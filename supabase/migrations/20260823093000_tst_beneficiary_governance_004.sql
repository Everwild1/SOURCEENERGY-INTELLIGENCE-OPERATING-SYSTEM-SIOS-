-- TST-WP05/WP06 beneficiary governance, compliance, conflicts, recusals, and independent approval prerequisites.

CREATE TABLE tst.beneficiaries (
  beneficiary_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  organization_oid text REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
  beneficiary_type text NOT NULL CHECK (beneficiary_type IN ('ORGANIZATION','INDIVIDUAL')),
  display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
  jurisdiction text,
  risk_tier text NOT NULL DEFAULT 'B1' CHECK (risk_tier IN ('B1','B2','B3')),
  eligibility_status text NOT NULL DEFAULT 'PROSPECT' CHECK (eligibility_status IN ('PROSPECT','ONBOARDING','DUE_DILIGENCE','PENDING_APPROVAL','APPROVED','ACTIVE','REVIEW_DUE','SUSPENDED','REJECTED','TERMINATED','ARCHIVED')),
  compliance_status text NOT NULL DEFAULT 'NOT_STARTED' CHECK (compliance_status IN ('NOT_STARTED','PENDING','CLEAR','POTENTIAL_MATCH','ESCALATED','RESOLVED_CLEAR','RESOLVED_BLOCK','EXPIRED')),
  conflict_status text NOT NULL DEFAULT 'NONE' CHECK (conflict_status IN ('NONE','POTENTIAL','DISCLOSED','UNDER_REVIEW','RECUSAL_REQUIRED','MITIGATION_REQUIRED','RESOLVED','PROHIBITED')),
  related_party boolean NOT NULL DEFAULT false,
  approved_at timestamptz,
  next_review_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((beneficiary_type='ORGANIZATION' AND organization_oid IS NOT NULL) OR beneficiary_type='INDIVIDUAL')
);
CREATE INDEX tst_beneficiaries_scope_idx ON tst.beneficiaries(stewardship_entity_id,eligibility_status,risk_tier);
CREATE INDEX tst_beneficiaries_review_idx ON tst.beneficiaries(next_review_date) WHERE next_review_date IS NOT NULL;

CREATE TABLE tst.beneficiary_reviews (
  review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_id uuid NOT NULL REFERENCES tst.beneficiaries(beneficiary_id) ON DELETE RESTRICT,
  review_type text NOT NULL,
  reviewer_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  review_status text NOT NULL DEFAULT 'PENDING' CHECK (review_status IN ('PENDING','PASS','FAIL','ESCALATED')),
  findings jsonb NOT NULL DEFAULT '{}'::jsonb,
  evidence_reference text,
  reviewed_at timestamptz,
  next_review_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tst.conflict_disclosures (
  conflict_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  beneficiary_id uuid REFERENCES tst.beneficiaries(beneficiary_id) ON DELETE RESTRICT,
  relationship_type text NOT NULL,
  description text NOT NULL CHECK (length(btrim(description)) > 0),
  severity text NOT NULL DEFAULT 'MODERATE' CHECK (severity IN ('LOW','MODERATE','HIGH','CRITICAL')),
  recusal_required boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'DISCLOSED' CHECK (status IN ('DISCLOSED','UNDER_REVIEW','RECUSAL_REQUIRED','MITIGATION_REQUIRED','RESOLVED','PROHIBITED')),
  disclosed_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution text
);
CREATE INDEX tst_conflicts_beneficiary_idx ON tst.conflict_disclosures(beneficiary_id,status);

CREATE TABLE tst.recusals (
  recusal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conflict_id uuid NOT NULL REFERENCES tst.conflict_disclosures(conflict_id) ON DELETE RESTRICT,
  participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  scope text NOT NULL,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('REQUIRED','RECORDED','ACTIVE','COMPLETED','REVOKED')),
  effective_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE tst.independent_approvals (
  independent_approval_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_id uuid NOT NULL REFERENCES tst.beneficiaries(beneficiary_id) ON DELETE RESTRICT,
  approver_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  approval_type text NOT NULL DEFAULT 'RELATED_PARTY_CLEARANCE',
  decision text NOT NULL CHECK (decision IN ('APPROVED','REJECTED','RETURNED','ABSTAINED','RECUSED')),
  decision_at timestamptz NOT NULL DEFAULT now(),
  authority_reference text,
  notes text
);

CREATE OR REPLACE FUNCTION tst_private.beneficiary_is_distribution_eligible(p_beneficiary_id uuid,p_as_of date DEFAULT current_date)
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
 SELECT EXISTS (
   SELECT 1 FROM tst.beneficiaries b
   WHERE b.beneficiary_id=p_beneficiary_id
     AND b.eligibility_status='ACTIVE'
     AND b.compliance_status IN ('CLEAR','RESOLVED_CLEAR')
     AND b.conflict_status NOT IN ('POTENTIAL','DISCLOSED','UNDER_REVIEW','RECUSAL_REQUIRED','MITIGATION_REQUIRED','PROHIBITED')
     AND (b.next_review_date IS NULL OR b.next_review_date>=p_as_of)
     AND (
       NOT b.related_party OR EXISTS (
         SELECT 1 FROM tst.independent_approvals ia
         JOIN tst.participants p ON p.participant_id=ia.approver_participant_id
         WHERE ia.beneficiary_id=b.beneficiary_id
           AND ia.decision='APPROVED'
           AND p.status='ACTIVE'
           AND NOT EXISTS (
             SELECT 1 FROM tst.conflict_disclosures cd
             WHERE cd.participant_id=p.participant_id
               AND cd.beneficiary_id=b.beneficiary_id
               AND cd.status IN ('DISCLOSED','UNDER_REVIEW','RECUSAL_REQUIRED','MITIGATION_REQUIRED','PROHIBITED')
           )
       )
     )
 );
$$;

CREATE OR REPLACE FUNCTION tst_private.enforce_independent_approval_integrity() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
BEGIN
 IF EXISTS (
   SELECT 1 FROM tst.conflict_disclosures cd
   WHERE cd.participant_id=NEW.approver_participant_id
     AND cd.beneficiary_id=NEW.beneficiary_id
     AND cd.status IN ('DISCLOSED','UNDER_REVIEW','RECUSAL_REQUIRED','MITIGATION_REQUIRED','PROHIBITED')
 ) THEN
   RAISE EXCEPTION 'conflicted participant cannot provide independent approval';
 END IF;
 IF EXISTS (
   SELECT 1 FROM tst.recusals r
   JOIN tst.conflict_disclosures cd ON cd.conflict_id=r.conflict_id
   WHERE r.participant_id=NEW.approver_participant_id
     AND cd.beneficiary_id=NEW.beneficiary_id
     AND r.status IN ('REQUIRED','RECORDED','ACTIVE')
 ) THEN
   RAISE EXCEPTION 'recused participant cannot provide independent approval';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tst_independent_approval_integrity
BEFORE INSERT OR UPDATE ON tst.independent_approvals
FOR EACH ROW EXECUTE FUNCTION tst_private.enforce_independent_approval_integrity();

ALTER TABLE tst.beneficiaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.beneficiary_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.conflict_disclosures ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.recusals ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.independent_approvals ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON tst.beneficiaries,tst.beneficiary_reviews,tst.conflict_disclosures,tst.recusals,tst.independent_approvals FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON tst.beneficiaries,tst.beneficiary_reviews,tst.conflict_disclosures,tst.recusals,tst.independent_approvals TO service_role;
CREATE POLICY beneficiaries_service_role_all ON tst.beneficiaries FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY beneficiary_reviews_service_role_all ON tst.beneficiary_reviews FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY conflicts_service_role_all ON tst.conflict_disclosures FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY recusals_service_role_all ON tst.recusals FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY independent_approvals_service_role_all ON tst.independent_approvals FOR ALL TO service_role USING(true) WITH CHECK(true);

REVOKE ALL ON FUNCTION tst_private.beneficiary_is_distribution_eligible(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION tst_private.beneficiary_is_distribution_eligible(uuid,date) TO service_role;
