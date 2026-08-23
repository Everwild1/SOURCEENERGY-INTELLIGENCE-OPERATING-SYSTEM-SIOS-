-- TST-WP13/WP14 oversight, compliance obligations, findings, remediation and closure evidence.
CREATE TABLE tst.compliance_obligations (
 obligation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 obligation_code text NOT NULL,
 title text NOT NULL,
 authority_source text NOT NULL,
 owner_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 cadence text NOT NULL DEFAULT 'EVENT_DRIVEN',
 next_due_date date,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','SUSPENDED','RETIRED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(stewardship_entity_id,obligation_code)
);
CREATE TABLE tst.control_findings (
 finding_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 obligation_id uuid REFERENCES tst.compliance_obligations(obligation_id) ON DELETE RESTRICT,
 finding_code text NOT NULL,
 severity text NOT NULL CHECK(severity IN ('LOW','MODERATE','HIGH','CRITICAL')),
 title text NOT NULL,
 description text NOT NULL,
 object_type text,
 object_id uuid,
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','TRIAGED','REMEDIATING','PENDING_VALIDATION','CLOSED','ACCEPTED_RISK')),
 detected_at timestamptz NOT NULL DEFAULT now(),
 due_at timestamptz,
 owner_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 closed_at timestamptz,
 UNIQUE(stewardship_entity_id,finding_code)
);
CREATE TABLE tst.remediation_actions (
 remediation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 finding_id uuid NOT NULL REFERENCES tst.control_findings(finding_id) ON DELETE RESTRICT,
 action_text text NOT NULL,
 owner_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','IN_PROGRESS','IMPLEMENTED','VALIDATED','REJECTED')),
 target_date date,
 implemented_at timestamptz,
 validated_by_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 validated_at timestamptz,
 closure_evidence_id uuid REFERENCES tst.evidence_records(evidence_id) ON DELETE RESTRICT
);
CREATE TABLE tst.compliance_reviews (
 review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 review_code text NOT NULL,
 period_start date NOT NULL,
 period_end date NOT NULL,
 reviewer_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'PLANNED' CHECK(status IN ('PLANNED','IN_PROGRESS','EXCEPTION','COMPLETE')),
 completed_at timestamptz,
 summary jsonb NOT NULL DEFAULT '{}'::jsonb,
 CHECK(period_end>=period_start), UNIQUE(stewardship_entity_id,review_code)
);

CREATE OR REPLACE FUNCTION tst_private.close_finding(p_finding_id uuid,p_validator_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE f tst.control_findings%ROWTYPE; e uuid; n integer;
BEGIN
 SELECT * INTO f FROM tst.control_findings WHERE finding_id=p_finding_id FOR UPDATE;
 IF NOT FOUND OR f.status NOT IN ('REMEDIATING','PENDING_VALIDATION') THEN RAISE EXCEPTION 'finding not closure-ready'; END IF;
 SELECT count(*) INTO n FROM tst.remediation_actions WHERE finding_id=p_finding_id AND status='VALIDATED' AND closure_evidence_id IS NOT NULL;
 IF n=0 THEN RAISE EXCEPTION 'validated remediation with closure evidence required'; END IF;
 IF EXISTS(SELECT 1 FROM tst.remediation_actions WHERE finding_id=p_finding_id AND status NOT IN ('VALIDATED','REJECTED')) THEN RAISE EXCEPTION 'open remediation remains'; END IF;
 UPDATE tst.control_findings SET status='CLOSED',closed_at=now() WHERE finding_id=p_finding_id;
 PERFORM tst_private.append_audit_event(f.stewardship_entity_id,p_validator_id,'CONTROL_FINDING_CLOSED','control_finding',p_finding_id,NULL,jsonb_build_object('finding_code',f.finding_code));
END $$;

CREATE OR REPLACE FUNCTION tst_private.entity_compliance_ready(p_entity_id uuid,p_as_of date DEFAULT current_date)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
 SELECT NOT EXISTS(SELECT 1 FROM tst.control_findings WHERE stewardship_entity_id=p_entity_id AND status NOT IN ('CLOSED','ACCEPTED_RISK') AND severity IN ('HIGH','CRITICAL'))
 AND NOT EXISTS(SELECT 1 FROM tst.compliance_obligations WHERE stewardship_entity_id=p_entity_id AND status='ACTIVE' AND next_due_date IS NOT NULL AND next_due_date<p_as_of);
$$;

CREATE INDEX tst_findings_status_idx ON tst.control_findings(stewardship_entity_id,status,severity,due_at);
CREATE INDEX tst_obligations_due_idx ON tst.compliance_obligations(stewardship_entity_id,next_due_date) WHERE status='ACTIVE';
ALTER TABLE tst.compliance_obligations ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.control_findings ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.remediation_actions ENABLE ROW LEVEL SECURITY; ALTER TABLE tst.compliance_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tst.compliance_obligations,tst.control_findings,tst.remediation_actions,tst.compliance_reviews FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON tst.compliance_obligations,tst.control_findings,tst.remediation_actions,tst.compliance_reviews TO service_role;
CREATE POLICY obligations_service_all ON tst.compliance_obligations FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY findings_service_all ON tst.control_findings FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY remediation_service_all ON tst.remediation_actions FOR ALL TO service_role USING(true) WITH CHECK(true); CREATE POLICY compliance_reviews_service_all ON tst.compliance_reviews FOR ALL TO service_role USING(true) WITH CHECK(true);
REVOKE ALL ON FUNCTION tst_private.close_finding(uuid,uuid) FROM PUBLIC,anon,authenticated; REVOKE ALL ON FUNCTION tst_private.entity_compliance_ready(uuid,date) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION tst_private.close_finding(uuid,uuid) TO service_role; GRANT EXECUTE ON FUNCTION tst_private.entity_compliance_ready(uuid,date) TO service_role;
