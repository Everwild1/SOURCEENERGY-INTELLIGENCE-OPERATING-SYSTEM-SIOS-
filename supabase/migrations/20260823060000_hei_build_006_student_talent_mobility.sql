-- HEI-BUILD-006 — Scholarships, Student Capital, Fellowships & Workforce Mobility Core
-- Privacy-first institutional records. Student records are not financial assets.

CREATE TABLE public.hei_talent_programs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
 program_reference text NOT NULL,
 program_type text NOT NULL CHECK (program_type IN ('SCHOLARSHIP','FELLOWSHIP','INTERNSHIP','APPRENTICESHIP','RESEARCH_ASSISTANTSHIP','WORKFORCE_PATHWAY','MOBILITY','OTHER')),
 name text NOT NULL,
 funding_program_id bigint REFERENCES public.hei_funding_programs(id),
 status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','ACTIVE','SUSPENDED','CLOSED')),
 governance_reference text,
 evidence_reference text,
 UNIQUE(organization_oid,program_reference)
);

CREATE TABLE public.hei_student_subjects (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
 subject_reference text NOT NULL,
 external_student_reference text,
 privacy_class text NOT NULL DEFAULT 'RESTRICTED' CHECK (privacy_class IN ('RESTRICTED','HIGHLY_RESTRICTED')),
 consent_reference text,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','WITHDRAWN','ARCHIVED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(organization_oid,subject_reference)
);

CREATE TABLE public.hei_talent_applications (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 talent_program_id bigint NOT NULL REFERENCES public.hei_talent_programs(id),
 student_subject_id bigint NOT NULL REFERENCES public.hei_student_subjects(id),
 application_reference text NOT NULL UNIQUE,
 eligibility_state text NOT NULL DEFAULT 'PENDING' CHECK (eligibility_state IN ('PENDING','ELIGIBLE','INELIGIBLE','CONDITIONAL')),
 review_status text NOT NULL DEFAULT 'SUBMITTED' CHECK (review_status IN ('DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','WITHDRAWN')),
 authority_reference text,
 evidence_reference text,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(talent_program_id,student_subject_id)
);

CREATE TABLE public.hei_talent_awards (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 talent_application_id bigint NOT NULL REFERENCES public.hei_talent_applications(id),
 award_reference text NOT NULL UNIQUE,
 award_amount numeric(20,4) CHECK (award_amount IS NULL OR award_amount >= 0),
 currency_code text CHECK (currency_code IS NULL OR currency_code ~ '^[A-Z]{3}$'),
 award_status text NOT NULL DEFAULT 'PROPOSED' CHECK (award_status IN ('PROPOSED','APPROVED','ACCEPTED','ACTIVE','COMPLETED','CANCELLED','REVOKED')),
 funding_award_id bigint REFERENCES public.hei_funding_awards(id),
 restriction_compatible boolean,
 authority_reference text,
 evidence_reference text
);

CREATE TABLE public.hei_talent_disbursement_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 talent_award_id bigint NOT NULL REFERENCES public.hei_talent_awards(id),
 disbursement_reference text NOT NULL UNIQUE,
 amount numeric(20,4) NOT NULL CHECK (amount > 0),
 currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
 disbursement_status text NOT NULL DEFAULT 'SCHEDULED' CHECK (disbursement_status IN ('SCHEDULED','REPORTED','CONFIRMED','RECONCILED','REVERSED')),
 external_transaction_reference text,
 occurred_at timestamptz,
 evidence_reference text
);

CREATE TABLE public.hei_workforce_placements (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 talent_award_id bigint REFERENCES public.hei_talent_awards(id),
 student_subject_id bigint NOT NULL REFERENCES public.hei_student_subjects(id),
 host_organization_oid text REFERENCES public.setc_organizations(oid),
 placement_reference text NOT NULL UNIQUE,
 placement_type text NOT NULL CHECK (placement_type IN ('INTERNSHIP','APPRENTICESHIP','EMPLOYMENT','FELLOWSHIP','RESEARCH','ENTREPRENEURSHIP','OTHER')),
 status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','MATCHED','ACCEPTED','ACTIVE','COMPLETED','WITHDRAWN','TERMINATED')),
 start_at timestamptz,
 end_at timestamptz,
 evidence_reference text,
 CHECK (end_at IS NULL OR start_at IS NULL OR end_at >= start_at)
);

CREATE TABLE public.hei_talent_outcomes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 student_subject_id bigint NOT NULL REFERENCES public.hei_student_subjects(id),
 talent_program_id bigint REFERENCES public.hei_talent_programs(id),
 outcome_type text NOT NULL CHECK (outcome_type IN ('RETENTION','COMPLETION','GRADUATION','PLACEMENT','CERTIFICATION','ENTREPRENEURSHIP','RESEARCH','OTHER')),
 outcome_state text NOT NULL,
 measured_at timestamptz NOT NULL DEFAULT now(),
 evidence_reference text
);

CREATE OR REPLACE FUNCTION public.hei_validate_talent_award() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE eligibility text; review_state text; restricted_state boolean;
BEGIN
 SELECT eligibility_state,review_status INTO eligibility,review_state FROM public.hei_talent_applications WHERE id=NEW.talent_application_id;
 IF NEW.award_status IN ('APPROVED','ACCEPTED','ACTIVE','COMPLETED') THEN
  IF eligibility <> 'ELIGIBLE' OR review_state <> 'APPROVED' THEN RAISE EXCEPTION 'eligible approved application required'; END IF;
  IF NEW.authority_reference IS NULL OR btrim(NEW.authority_reference)='' THEN RAISE EXCEPTION 'award authority required'; END IF;
  IF NEW.funding_award_id IS NOT NULL THEN
   SELECT restricted INTO restricted_state FROM public.hei_funding_awards WHERE id=NEW.funding_award_id;
   IF restricted_state AND NEW.restriction_compatible IS DISTINCT FROM true THEN RAISE EXCEPTION 'funding restriction compatibility required'; END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER hei_talent_award_gate BEFORE INSERT OR UPDATE ON public.hei_talent_awards FOR EACH ROW EXECUTE FUNCTION public.hei_validate_talent_award();

CREATE OR REPLACE FUNCTION public.hei_validate_talent_disbursement() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE award_state text;
BEGIN
 SELECT award_status INTO award_state FROM public.hei_talent_awards WHERE id=NEW.talent_award_id;
 IF NEW.disbursement_status IN ('CONFIRMED','RECONCILED') THEN
  IF award_state NOT IN ('ACCEPTED','ACTIVE','COMPLETED') THEN RAISE EXCEPTION 'accepted talent award required'; END IF;
  IF NEW.occurred_at IS NULL OR NEW.external_transaction_reference IS NULL OR btrim(NEW.external_transaction_reference)='' OR NEW.evidence_reference IS NULL OR btrim(NEW.evidence_reference)='' THEN RAISE EXCEPTION 'confirmed disbursement requires occurrence, external transaction reference and evidence'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER hei_talent_disbursement_gate BEFORE INSERT OR UPDATE ON public.hei_talent_disbursement_events FOR EACH ROW EXECUTE FUNCTION public.hei_validate_talent_disbursement();

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['hei_talent_programs','hei_student_subjects','hei_talent_applications','hei_talent_awards','hei_talent_disbursement_events','hei_workforce_placements','hei_talent_outcomes'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated',t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)',t||'_service_role_all',t);
 END LOOP;
END $$;

COMMENT ON TABLE public.hei_student_subjects IS 'Institution-scoped pseudonymous student subject registry. Do not store unnecessary direct identifiers. Student records are not financial assets.';
COMMENT ON TABLE public.hei_talent_disbursement_events IS 'Disbursement evidence/reference layer only; does not create bank custody or settlement finality.';
COMMENT ON TABLE public.hei_talent_outcomes IS 'Restricted student-level outcome evidence; cross-institution reporting should use separately governed de-identified or aggregate products.';
