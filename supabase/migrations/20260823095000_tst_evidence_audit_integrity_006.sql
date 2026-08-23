-- TST-WP09/WP10 evidence custody, provenance, and append-only audit integrity.
CREATE TABLE tst.evidence_records (
 evidence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 evidence_type text NOT NULL,
 subject_type text NOT NULL,
 subject_id uuid,
 storage_provider text NOT NULL,
 storage_locator text NOT NULL,
 content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
 media_type text,
 byte_size bigint CHECK (byte_size IS NULL OR byte_size >= 0),
 captured_by_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 captured_at timestamptz NOT NULL DEFAULT now(),
 retention_until date,
 legal_hold boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUPERSEDED','RETAINED','QUARANTINED')),
 UNIQUE(stewardship_entity_id,content_sha256)
);

CREATE TABLE tst.evidence_links (
 evidence_link_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 evidence_id uuid NOT NULL REFERENCES tst.evidence_records(evidence_id) ON DELETE RESTRICT,
 object_type text NOT NULL,
 object_id uuid NOT NULL,
 relationship text NOT NULL DEFAULT 'SUPPORTS',
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(evidence_id,object_type,object_id,relationship)
);

CREATE TABLE tst.audit_events (
 audit_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 sequence_no bigint NOT NULL,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 actor_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 action_code text NOT NULL,
 object_type text NOT NULL,
 object_id uuid,
 correlation_id uuid,
 event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 previous_hash text CHECK (previous_hash IS NULL OR previous_hash ~ '^[0-9a-f]{64}$'),
 event_hash text NOT NULL CHECK (event_hash ~ '^[0-9a-f]{64}$'),
 UNIQUE(stewardship_entity_id,sequence_no),
 UNIQUE(stewardship_entity_id,event_hash)
);

CREATE INDEX tst_evidence_subject_idx ON tst.evidence_records(subject_type,subject_id,status);
CREATE INDEX tst_evidence_links_object_idx ON tst.evidence_links(object_type,object_id);
CREATE INDEX tst_audit_object_idx ON tst.audit_events(object_type,object_id,occurred_at);
CREATE INDEX tst_audit_correlation_idx ON tst.audit_events(correlation_id) WHERE correlation_id IS NOT NULL;

CREATE OR REPLACE FUNCTION tst_private.append_audit_event(
 p_entity_id uuid,p_actor_id uuid,p_action_code text,p_object_type text,p_object_id uuid,p_correlation_id uuid,p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private,public,extensions AS $$
DECLARE seq bigint; prev text; eid uuid; ts timestamptz:=clock_timestamp(); digest_text text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_entity_id::text,0));
 SELECT sequence_no,event_hash INTO seq,prev FROM tst.audit_events WHERE stewardship_entity_id=p_entity_id ORDER BY sequence_no DESC LIMIT 1;
 seq:=COALESCE(seq,0)+1;
 digest_text:=encode(digest(concat_ws('|',p_entity_id::text,seq::text,ts::text,COALESCE(p_actor_id::text,''),p_action_code,p_object_type,COALESCE(p_object_id::text,''),COALESCE(p_correlation_id::text,''),COALESCE(p_payload,'{}'::jsonb)::text,COALESCE(prev,'')),'sha256'),'hex');
 INSERT INTO tst.audit_events(stewardship_entity_id,sequence_no,occurred_at,actor_participant_id,action_code,object_type,object_id,correlation_id,event_payload,previous_hash,event_hash)
 VALUES(p_entity_id,seq,ts,p_actor_id,p_action_code,p_object_type,p_object_id,p_correlation_id,COALESCE(p_payload,'{}'::jsonb),prev,digest_text)
 RETURNING audit_event_id INTO eid;
 RETURN eid;
END $$;

CREATE OR REPLACE FUNCTION tst_private.block_audit_mutation() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'audit events are append-only'; END $$;
CREATE TRIGGER tst_audit_no_update_delete BEFORE UPDATE OR DELETE ON tst.audit_events FOR EACH ROW EXECUTE FUNCTION tst_private.block_audit_mutation();

CREATE OR REPLACE FUNCTION tst_private.verify_audit_chain(p_entity_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst,public,extensions AS $$
DECLARE r record; expected_prev text:=NULL; expected_hash text;
BEGIN
 FOR r IN SELECT * FROM tst.audit_events WHERE stewardship_entity_id=p_entity_id ORDER BY sequence_no LOOP
   IF r.previous_hash IS DISTINCT FROM expected_prev THEN RETURN false; END IF;
   expected_hash:=encode(digest(concat_ws('|',r.stewardship_entity_id::text,r.sequence_no::text,r.occurred_at::text,COALESCE(r.actor_participant_id::text,''),r.action_code,r.object_type,COALESCE(r.object_id::text,''),COALESCE(r.correlation_id::text,''),COALESCE(r.event_payload,'{}'::jsonb)::text,COALESCE(r.previous_hash,'')),'sha256'),'hex');
   IF expected_hash<>r.event_hash THEN RETURN false; END IF;
   expected_prev:=r.event_hash;
 END LOOP;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION tst_private.block_evidence_identity_mutation() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.content_sha256<>OLD.content_sha256 OR NEW.storage_locator<>OLD.storage_locator OR NEW.stewardship_entity_id<>OLD.stewardship_entity_id THEN
   RAISE EXCEPTION 'evidence identity fields are immutable';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tst_evidence_identity_immutable BEFORE UPDATE ON tst.evidence_records FOR EACH ROW EXECUTE FUNCTION tst_private.block_evidence_identity_mutation();

ALTER TABLE tst.evidence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.evidence_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tst.evidence_records,tst.evidence_links,tst.audit_events FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON tst.evidence_records,tst.evidence_links TO service_role;
GRANT SELECT,INSERT ON tst.audit_events TO service_role;
CREATE POLICY evidence_records_service_role_all ON tst.evidence_records FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY evidence_links_service_role_all ON tst.evidence_links FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY audit_events_service_role_select ON tst.audit_events FOR SELECT TO service_role USING(true);
CREATE POLICY audit_events_service_role_insert ON tst.audit_events FOR INSERT TO service_role WITH CHECK(true);
REVOKE ALL ON FUNCTION tst_private.append_audit_event(uuid,uuid,text,text,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.verify_audit_chain(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION tst_private.append_audit_event(uuid,uuid,text,text,uuid,uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.verify_audit_chain(uuid) TO service_role;
