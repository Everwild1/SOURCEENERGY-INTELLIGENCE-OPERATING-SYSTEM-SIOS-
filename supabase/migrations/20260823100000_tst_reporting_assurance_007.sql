-- TST-WP11/WP12 reporting, attestations, assurance packages, and period close.
CREATE TABLE tst.reporting_periods (
 reporting_period_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 period_code text NOT NULL,
 period_start date NOT NULL,
 period_end date NOT NULL,
 status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','PRE_CLOSE','CLOSED','REOPENED')),
 closed_by_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 closed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(period_end>=period_start), UNIQUE(stewardship_entity_id,period_code)
);
CREATE TABLE tst.stewardship_statements (
 statement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reporting_period_id uuid NOT NULL REFERENCES tst.reporting_periods(reporting_period_id) ON DELETE RESTRICT,
 statement_type text NOT NULL CHECK(statement_type IN ('FUND_ACTIVITY','CONTRIBUTION','DISTRIBUTION','BENEFICIARY','RECONCILIATION','TRUSTEE_STEWARDSHIP')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 generated_at timestamptz NOT NULL DEFAULT now(),
 generated_by_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 statement_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 payload_sha256 text NOT NULL CHECK(payload_sha256 ~ '^[0-9a-f]{64}$'),
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','FINAL','SUPERSEDED')),
 UNIQUE(reporting_period_id,statement_type,version)
);
CREATE TABLE tst.trustee_attestations (
 attestation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 statement_id uuid NOT NULL REFERENCES tst.stewardship_statements(statement_id) ON DELETE RESTRICT,
 trustee_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 attestation_code text NOT NULL,
 decision text NOT NULL CHECK(decision IN ('ATTESTED','QUALIFIED','DECLINED','RECUSED')),
 qualification text,
 attested_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(statement_id,trustee_participant_id,attestation_code)
);
CREATE TABLE tst.assurance_packages (
 assurance_package_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reporting_period_id uuid NOT NULL REFERENCES tst.reporting_periods(reporting_period_id) ON DELETE RESTRICT,
 package_code text NOT NULL,
 manifest jsonb NOT NULL DEFAULT '{}'::jsonb,
 manifest_sha256 text NOT NULL CHECK(manifest_sha256 ~ '^[0-9a-f]{64}$'),
 evidence_complete boolean NOT NULL DEFAULT false,
 audit_chain_verified boolean NOT NULL DEFAULT false,
 reconciliation_complete boolean NOT NULL DEFAULT false,
 trustee_attested boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'ASSEMBLING' CHECK(status IN ('ASSEMBLING','READY','ISSUED','WITHDRAWN')),
 issued_at timestamptz,
 UNIQUE(reporting_period_id,package_code)
);

CREATE OR REPLACE FUNCTION tst_private.period_assurance_ready(p_period_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE rp tst.reporting_periods%ROWTYPE; chain_ok boolean; unresolved integer; attested integer; final_statements integer;
BEGIN
 SELECT * INTO rp FROM tst.reporting_periods WHERE reporting_period_id=p_period_id;
 IF NOT FOUND THEN RETURN false; END IF;
 SELECT tst_private.verify_audit_chain(rp.stewardship_entity_id) INTO chain_ok;
 SELECT count(*) INTO unresolved FROM tst.distributions d JOIN tst.allocations a ON a.allocation_id=d.allocation_id JOIN tst.funds f ON f.fund_id=a.fund_id
 WHERE f.stewardship_entity_id=rp.stewardship_entity_id AND d.created_at::date BETWEEN rp.period_start AND rp.period_end AND d.status IN ('PAYMENT_EXECUTED','SETTLED','RECONCILIATION_PENDING','HOLD');
 SELECT count(*) INTO final_statements FROM tst.stewardship_statements WHERE reporting_period_id=p_period_id AND status='FINAL';
 SELECT count(*) INTO attested FROM tst.trustee_attestations ta JOIN tst.stewardship_statements s ON s.statement_id=ta.statement_id WHERE s.reporting_period_id=p_period_id AND s.status='FINAL' AND ta.decision='ATTESTED';
 RETURN chain_ok AND unresolved=0 AND final_statements>0 AND attested>0;
END $$;

CREATE OR REPLACE FUNCTION tst_private.issue_assurance_package(p_package_id uuid,p_actor_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE ap tst.assurance_packages%ROWTYPE; rp tst.reporting_periods%ROWTYPE; ready boolean;
BEGIN
 SELECT * INTO ap FROM tst.assurance_packages WHERE assurance_package_id=p_package_id FOR UPDATE;
 IF NOT FOUND OR ap.status<>'READY' THEN RAISE EXCEPTION 'assurance package not READY'; END IF;
 SELECT * INTO rp FROM tst.reporting_periods WHERE reporting_period_id=ap.reporting_period_id FOR UPDATE;
 SELECT tst_private.period_assurance_ready(rp.reporting_period_id) INTO ready;
 IF NOT ready OR NOT ap.evidence_complete OR NOT ap.audit_chain_verified OR NOT ap.reconciliation_complete OR NOT ap.trustee_attested THEN RAISE EXCEPTION 'assurance prerequisites incomplete'; END IF;
 UPDATE tst.assurance_packages SET status='ISSUED',issued_at=now() WHERE assurance_package_id=p_package_id;
 UPDATE tst.reporting_periods SET status='CLOSED',closed_by_participant_id=p_actor_id,closed_at=now() WHERE reporting_period_id=rp.reporting_period_id;
 PERFORM tst_private.append_audit_event(rp.stewardship_entity_id,p_actor_id,'ASSURANCE_PACKAGE_ISSUED','assurance_package',p_package_id,NULL,jsonb_build_object('period_code',rp.period_code));
END $$;

CREATE OR REPLACE FUNCTION tst_private.block_final_statement_mutation() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN IF OLD.status='FINAL' THEN RAISE EXCEPTION 'final stewardship statement is immutable'; END IF; RETURN NEW; END $$;
CREATE TRIGGER tst_final_statement_immutable BEFORE UPDATE OR DELETE ON tst.stewardship_statements FOR EACH ROW EXECUTE FUNCTION tst_private.block_final_statement_mutation();

ALTER TABLE tst.reporting_periods ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.stewardship_statements ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.trustee_attestations ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.assurance_packages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tst.reporting_periods,tst.stewardship_statements,tst.trustee_attestations,tst.assurance_packages FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON tst.reporting_periods,tst.stewardship_statements,tst.trustee_attestations,tst.assurance_packages TO service_role;
CREATE POLICY reporting_periods_service_all ON tst.reporting_periods FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY statements_service_all ON tst.stewardship_statements FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY attestations_service_all ON tst.trustee_attestations FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY assurance_service_all ON tst.assurance_packages FOR ALL TO service_role USING(true) WITH CHECK(true);
REVOKE ALL ON FUNCTION tst_private.period_assurance_ready(uuid) FROM PUBLIC,anon,authenticated; REVOKE ALL ON FUNCTION tst_private.issue_assurance_package(uuid,uuid) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION tst_private.period_assurance_ready(uuid) TO service_role; GRANT EXECUTE ON FUNCTION tst_private.issue_assurance_package(uuid,uuid) TO service_role;
