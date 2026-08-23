-- HEI-BUILD-004 — Capital Formation, Investment Participation & Institutional Opportunity Core
-- Opportunity discovery and participation do not create financing commitments, custody, or endowment authority.

CREATE TABLE public.hei_investment_opportunities (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  opportunity_reference text NOT NULL UNIQUE,
  sponsor_organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  opportunity_type text NOT NULL CHECK (opportunity_type IN ('PUBLIC_MARKET','PRIVATE_FUND','PRIVATE_COMPANY','PROJECT','CREDIT','REAL_ASSET','CO_INVESTMENT','OTHER')),
  title text NOT NULL,
  currency_code text CHECK (currency_code IS NULL OR currency_code ~ '^[A-Z]{3}$'),
  target_raise_amount numeric(20,4) CHECK (target_raise_amount IS NULL OR target_raise_amount >= 0),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','DUE_DILIGENCE','APPROVED_FOR_DISTRIBUTION','OPEN','PAUSED','CLOSED','REJECTED')),
  governance_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.hei_opportunity_eligibility_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  opportunity_id bigint NOT NULL REFERENCES public.hei_investment_opportunities(id) ON DELETE CASCADE,
  rule_type text NOT NULL CHECK (rule_type IN ('INSTITUTION_TYPE','JURISDICTION','MANDATE','LIQUIDITY','RISK','MINIMUM_COMMITMENT','MAXIMUM_EXPOSURE','OTHER')),
  rule_value text NOT NULL,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','RETIRED')),
  evidence_reference text
);

CREATE TABLE public.hei_opportunity_diligence (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  opportunity_id bigint NOT NULL REFERENCES public.hei_investment_opportunities(id) ON DELETE CASCADE,
  diligence_type text NOT NULL CHECK (diligence_type IN ('LEGAL','FINANCIAL','INVESTMENT','RISK','OPERATIONAL','ESG_IMPACT','COMPLIANCE','OTHER')),
  diligence_status text NOT NULL DEFAULT 'PENDING' CHECK (diligence_status IN ('PENDING','IN_PROGRESS','PASSED','PASSED_WITH_CONDITIONS','FAILED','WAIVED')),
  reviewer_reference text,
  conclusion text,
  evidence_reference text,
  reviewed_at timestamptz
);

CREATE TABLE public.hei_institution_opportunity_reviews (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  opportunity_id bigint NOT NULL REFERENCES public.hei_investment_opportunities(id),
  endowment_pool_id bigint REFERENCES public.hei_endowment_pools(id),
  mandate_id bigint REFERENCES public.hei_investment_mandates(id),
  ips_id bigint REFERENCES public.hei_investment_policy_statements(id),
  fiduciary_authority_id bigint REFERENCES public.hei_fiduciary_authorities(id),
  review_status text NOT NULL DEFAULT 'DRAFT' CHECK (review_status IN ('DRAFT','DUE_DILIGENCE','IPS_CHECK','RISK_REVIEW','COMPLIANCE_REVIEW','APPROVED','REJECTED','WITHDRAWN')),
  ips_compatible boolean,
  restriction_compatible boolean,
  liquidity_compatible boolean,
  conflict_review_state text NOT NULL DEFAULT 'PENDING' CHECK (conflict_review_state IN ('PENDING','CLEARED','ESCALATED','BLOCKED')),
  authority_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(organization_oid, opportunity_id, endowment_pool_id)
);

CREATE TABLE public.hei_investment_indications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  institution_review_id bigint NOT NULL REFERENCES public.hei_institution_opportunity_reviews(id),
  indicated_amount numeric(20,4) NOT NULL CHECK (indicated_amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'INDICATIVE' CHECK (status IN ('INDICATIVE','CONFIRMED','WITHDRAWN','EXPIRED')),
  expires_at timestamptz,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.hei_investment_commitments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  institution_review_id bigint NOT NULL REFERENCES public.hei_institution_opportunity_reviews(id),
  commitment_reference text NOT NULL UNIQUE,
  committed_amount numeric(20,4) NOT NULL CHECK (committed_amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','APPROVED','COMMITTED','PARTIALLY_FUNDED','FUNDED','CANCELLED','DEFAULTED','CLOSED')),
  funded_amount numeric(20,4) NOT NULL DEFAULT 0 CHECK (funded_amount >= 0),
  external_transaction_reference text,
  authority_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (funded_amount <= committed_amount)
);

CREATE TABLE public.hei_opportunity_wim_links (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  opportunity_id bigint NOT NULL REFERENCES public.hei_investment_opportunities(id) ON DELETE CASCADE,
  wim_opportunity_reference text NOT NULL,
  status text NOT NULL DEFAULT 'REFERENCE_ONLY' CHECK (status IN ('REFERENCE_ONLY','PUBLISHED','SUSPENDED','RETIRED')),
  evidence_reference text,
  UNIQUE(opportunity_id, wim_opportunity_reference)
);

CREATE OR REPLACE FUNCTION public.hei_validate_institution_opportunity_review()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  pool_status text;
  mandate_status text;
  ips_status text;
  authority_status text;
BEGIN
  IF NEW.review_status = 'APPROVED' THEN
    IF NEW.endowment_pool_id IS NULL OR NEW.mandate_id IS NULL OR NEW.ips_id IS NULL OR NEW.fiduciary_authority_id IS NULL THEN
      RAISE EXCEPTION 'approved participation requires pool, mandate, IPS and fiduciary authority';
    END IF;
    SELECT status INTO pool_status FROM public.hei_endowment_pools WHERE id=NEW.endowment_pool_id;
    SELECT status INTO mandate_status FROM public.hei_investment_mandates WHERE id=NEW.mandate_id;
    SELECT status INTO ips_status FROM public.hei_investment_policy_statements WHERE id=NEW.ips_id;
    SELECT status INTO authority_status FROM public.hei_fiduciary_authorities WHERE id=NEW.fiduciary_authority_id;
    IF pool_status <> 'ACTIVE' THEN RAISE EXCEPTION 'active endowment pool required'; END IF;
    IF mandate_status <> 'ACTIVE' THEN RAISE EXCEPTION 'active investment mandate required'; END IF;
    IF ips_status <> 'APPROVED' THEN RAISE EXCEPTION 'approved IPS required'; END IF;
    IF authority_status <> 'ACTIVE' THEN RAISE EXCEPTION 'active fiduciary authority required'; END IF;
    IF NEW.ips_compatible IS DISTINCT FROM true OR NEW.restriction_compatible IS DISTINCT FROM true OR NEW.liquidity_compatible IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'IPS, restriction and liquidity compatibility required';
    END IF;
    IF NEW.conflict_review_state <> 'CLEARED' THEN RAISE EXCEPTION 'cleared conflict review required'; END IF;
    IF NEW.authority_reference IS NULL OR btrim(NEW.authority_reference)='' THEN RAISE EXCEPTION 'authority reference required'; END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER hei_institution_opportunity_review_gate
BEFORE INSERT OR UPDATE ON public.hei_institution_opportunity_reviews
FOR EACH ROW EXECUTE FUNCTION public.hei_validate_institution_opportunity_review();

CREATE OR REPLACE FUNCTION public.hei_validate_investment_commitment()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE review_state text;
BEGIN
  SELECT review_status INTO review_state FROM public.hei_institution_opportunity_reviews WHERE id=NEW.institution_review_id;
  IF NEW.status IN ('APPROVED','COMMITTED','PARTIALLY_FUNDED','FUNDED','CLOSED') AND review_state <> 'APPROVED' THEN
    RAISE EXCEPTION 'approved institutional opportunity review required';
  END IF;
  IF NEW.status IN ('COMMITTED','PARTIALLY_FUNDED','FUNDED','CLOSED') AND (NEW.authority_reference IS NULL OR btrim(NEW.authority_reference)='') THEN
    RAISE EXCEPTION 'commitment authority required';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER hei_investment_commitment_gate
BEFORE INSERT OR UPDATE ON public.hei_investment_commitments
FOR EACH ROW EXECUTE FUNCTION public.hei_validate_investment_commitment();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'hei_investment_opportunities','hei_opportunity_eligibility_rules','hei_opportunity_diligence',
    'hei_institution_opportunity_reviews','hei_investment_indications','hei_investment_commitments','hei_opportunity_wim_links'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)', t || '_service_role_all', t);
  END LOOP;
END $$;

COMMENT ON TABLE public.hei_investment_opportunities IS 'Opportunity registry only; publication or discovery does not constitute an offer, commitment, suitability determination, custody, or settlement finality.';
COMMENT ON TABLE public.hei_investment_indications IS 'Indications are non-cash, non-funded expressions of interest unless separately committed and funded under governed controls.';
COMMENT ON TABLE public.hei_opportunity_wim_links IS 'WIM linkage is reference/publication metadata only; WIM does not become institutional fiduciary or accounting authority.';
