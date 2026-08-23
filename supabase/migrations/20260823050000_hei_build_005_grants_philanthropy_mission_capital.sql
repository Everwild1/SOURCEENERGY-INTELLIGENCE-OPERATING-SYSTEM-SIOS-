-- HEI-BUILD-005 — Grants, Sponsored Programs, Philanthropy & Mission-Capital Core
-- Pledges, awards, receipts, allocations and spendable balances remain distinct states.

CREATE TABLE public.hei_funding_programs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  program_reference text NOT NULL,
  program_type text NOT NULL CHECK (program_type IN ('GRANT','SPONSORED_PROGRAM','PHILANTHROPY','MISSION_CAPITAL','SCHOLARSHIP','CHAIR','FELLOWSHIP','OTHER')),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','ACTIVE','SUSPENDED','CLOSED')),
  governance_reference text,
  evidence_reference text,
  UNIQUE(organization_oid, program_reference)
);

CREATE TABLE public.hei_funding_sources (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_organization_oid text REFERENCES public.setc_organizations(oid),
  source_reference text NOT NULL UNIQUE,
  source_type text NOT NULL CHECK (source_type IN ('FEDERAL','STATE_LOCAL','FOUNDATION','CORPORATE','ALUMNI','DIASPORA','INDIVIDUAL','INSTITUTIONAL','MULTILATERAL','OTHER')),
  name text NOT NULL,
  evidence_reference text
);

CREATE TABLE public.hei_funding_awards (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  funding_program_id bigint NOT NULL REFERENCES public.hei_funding_programs(id),
  funding_source_id bigint REFERENCES public.hei_funding_sources(id),
  award_reference text NOT NULL UNIQUE,
  award_type text NOT NULL CHECK (award_type IN ('GRANT_AWARD','SPONSORED_AWARD','GIFT','PLEDGE','MISSION_CAPITAL_ALLOCATION','OTHER')),
  awarded_amount numeric(20,4) NOT NULL CHECK (awarded_amount >= 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','DOCUMENTED','ACCEPTED','ACTIVE','PARTIALLY_RECEIVED','RECEIVED','CLOSED','CANCELLED')),
  restricted boolean NOT NULL DEFAULT false,
  authority_reference text,
  agreement_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.hei_funding_restrictions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  funding_award_id bigint NOT NULL REFERENCES public.hei_funding_awards(id) ON DELETE CASCADE,
  restriction_type text NOT NULL,
  purpose text,
  permitted_uses text,
  prohibited_uses text,
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_reference text,
  CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at >= effective_at)
);

CREATE TABLE public.hei_funding_receipts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  funding_award_id bigint NOT NULL REFERENCES public.hei_funding_awards(id),
  receipt_reference text NOT NULL UNIQUE,
  gross_amount numeric(20,4) NOT NULL CHECK (gross_amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  received_at timestamptz,
  reconciliation_status text NOT NULL DEFAULT 'REPORTED' CHECK (reconciliation_status IN ('REPORTED','RECEIVED','RECONCILING','RECONCILED','ACCEPTED','REVERSED')),
  external_account_reference text,
  evidence_reference text
);

CREATE TABLE public.hei_funding_allocations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  funding_award_id bigint NOT NULL REFERENCES public.hei_funding_awards(id),
  allocation_reference text NOT NULL UNIQUE,
  destination_type text NOT NULL CHECK (destination_type IN ('OPERATING_PROGRAM','RESEARCH_PROJECT','ENDOWMENT_POOL','SCHOLARSHIP','CHAIR','FELLOWSHIP','DEVELOPMENT_PROJECT','OTHER')),
  destination_reference text NOT NULL,
  allocated_amount numeric(20,4) NOT NULL CHECK (allocated_amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  restriction_compatible boolean,
  authority_reference text,
  status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','APPROVED','ACTIVE','REVERSED','CLOSED')),
  evidence_reference text
);

CREATE TABLE public.hei_stewardship_obligations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  funding_award_id bigint NOT NULL REFERENCES public.hei_funding_awards(id) ON DELETE CASCADE,
  obligation_type text NOT NULL CHECK (obligation_type IN ('ACKNOWLEDGEMENT','REPORTING','NAMING','IMPACT_REPORT','FINANCIAL_REPORT','OTHER')),
  due_at timestamptz,
  status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_PROGRESS','COMPLETED','WAIVED','OVERDUE')),
  owner_reference text,
  evidence_reference text
);

CREATE OR REPLACE FUNCTION public.hei_validate_funding_allocation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  award_state text;
  award_restricted boolean;
BEGIN
  SELECT status, restricted INTO award_state, award_restricted
  FROM public.hei_funding_awards WHERE id=NEW.funding_award_id;

  IF NEW.status IN ('APPROVED','ACTIVE','CLOSED') THEN
    IF award_state NOT IN ('ACCEPTED','ACTIVE','PARTIALLY_RECEIVED','RECEIVED','CLOSED') THEN
      RAISE EXCEPTION 'accepted funding award required';
    END IF;
    IF award_restricted AND NEW.restriction_compatible IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'restriction compatibility required';
    END IF;
    IF NEW.authority_reference IS NULL OR btrim(NEW.authority_reference)='' THEN
      RAISE EXCEPTION 'allocation authority required';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER hei_funding_allocation_gate
BEFORE INSERT OR UPDATE ON public.hei_funding_allocations
FOR EACH ROW EXECUTE FUNCTION public.hei_validate_funding_allocation();

CREATE OR REPLACE FUNCTION public.hei_validate_funding_receipt()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.reconciliation_status IN ('RECONCILED','ACCEPTED') THEN
    IF NEW.received_at IS NULL THEN RAISE EXCEPTION 'received_at required for reconciled receipt'; END IF;
    IF NEW.evidence_reference IS NULL OR btrim(NEW.evidence_reference)='' THEN RAISE EXCEPTION 'receipt evidence required'; END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER hei_funding_receipt_gate
BEFORE INSERT OR UPDATE ON public.hei_funding_receipts
FOR EACH ROW EXECUTE FUNCTION public.hei_validate_funding_receipt();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'hei_funding_programs','hei_funding_sources','hei_funding_awards','hei_funding_restrictions',
    'hei_funding_receipts','hei_funding_allocations','hei_stewardship_obligations'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)', t || '_service_role_all', t);
  END LOOP;
END $$;

COMMENT ON TABLE public.hei_funding_awards IS 'Award and pledge records are not bank cash. Receipt, reconciliation, acceptance and allocation remain distinct.';
COMMENT ON TABLE public.hei_funding_receipts IS 'Evidence-backed receipt events only; does not duplicate custody or bank account ledgers.';
COMMENT ON TABLE public.hei_funding_allocations IS 'Allocation authority is institution-controlled and must preserve restrictions; endowment destination does not bypass HEI endowment governance.';
