-- HEI-BUILD-002 / issue #144
-- Endowment and fiduciary governance core. External custody/account systems remain referenced, not duplicated.

CREATE TABLE public.hei_fiduciary_authorities (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  authority_type text NOT NULL CHECK (authority_type IN ('BOARD','INVESTMENT_COMMITTEE','CIO_STAFF','EXTERNAL_ADVISER','INVESTMENT_MANAGER','CUSTODIAN','OTHER')),
  authority_scope text NOT NULL,
  delegation_reference text,
  status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','APPROVED','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at >= effective_at)
);

CREATE TABLE public.hei_endowment_pools (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  legal_owner_organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  pool_reference text NOT NULL,
  pool_type text NOT NULL CHECK (pool_type IN ('CORE_ENDOWMENT','OPERATING_LIQUIDITY','STRATEGIC_OPPORTUNITY','MISSION_IMPACT','BOARD_DESIGNATED','DONOR_RESTRICTED','TERM_ENDOWMENT','OTHER')),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','CLOSED')),
  endowment_cross_collateralization boolean NOT NULL DEFAULT false,
  governance_reference text,
  evidence_reference text,
  effective_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_oid, pool_reference)
);

CREATE TABLE public.hei_investment_policy_statements (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  policy_reference text NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','SUPERSEDED','SUSPENDED','REVOKED')),
  effective_at timestamptz,
  review_due_at timestamptz,
  approved_by_authority_id bigint REFERENCES public.hei_fiduciary_authorities(id),
  document_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_oid, policy_reference, version),
  CHECK (review_due_at IS NULL OR effective_at IS NULL OR review_due_at >= effective_at)
);

CREATE TABLE public.hei_fund_restrictions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  restriction_type text NOT NULL,
  purpose text,
  restriction_source text NOT NULL,
  restriction_reference text,
  permitted_uses text,
  prohibited_uses text,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','EXPIRED','RELEASED')),
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_reference text,
  CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at >= effective_at)
);

CREATE TABLE public.hei_spending_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  calculation_method text NOT NULL,
  spending_rate numeric(9,6) CHECK (spending_rate IS NULL OR (spending_rate >= 0 AND spending_rate <= 1)),
  measurement_period text,
  minimum_liquidity_requirement numeric(20,4) CHECK (minimum_liquidity_requirement IS NULL OR minimum_liquidity_requirement >= 0),
  restriction_override_prohibited boolean NOT NULL DEFAULT true,
  approved_by_authority_id bigint REFERENCES public.hei_fiduciary_authorities(id),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','APPROVED','ACTIVE','SUSPENDED','SUPERSEDED','REVOKED')),
  effective_at timestamptz,
  evidence_reference text
);

CREATE TABLE public.hei_investment_mandates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  mandate_type text NOT NULL,
  manager_organization_oid text REFERENCES public.setc_organizations(oid),
  adviser_organization_oid text REFERENCES public.setc_organizations(oid),
  external_custody_reference text,
  authority_reference text NOT NULL,
  status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','APPROVED','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_reference text,
  CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at >= effective_at)
);

CREATE TABLE public.hei_strategic_allocations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  ips_id bigint NOT NULL REFERENCES public.hei_investment_policy_statements(id),
  asset_class text NOT NULL,
  target_weight numeric(9,6) NOT NULL CHECK (target_weight BETWEEN 0 AND 1),
  minimum_weight numeric(9,6) NOT NULL CHECK (minimum_weight BETWEEN 0 AND 1),
  maximum_weight numeric(9,6) NOT NULL CHECK (maximum_weight BETWEEN 0 AND 1),
  liquidity_bucket text,
  benchmark_reference text,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','SUPERSEDED')),
  effective_at timestamptz,
  CHECK (minimum_weight <= target_weight AND target_weight <= maximum_weight),
  UNIQUE (endowment_pool_id, ips_id, asset_class)
);

CREATE TABLE public.hei_investment_decisions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  mandate_id bigint REFERENCES public.hei_investment_mandates(id),
  ips_id bigint NOT NULL REFERENCES public.hei_investment_policy_statements(id),
  decision_authority_id bigint NOT NULL REFERENCES public.hei_fiduciary_authorities(id),
  lifecycle_state text NOT NULL DEFAULT 'DRAFT' CHECK (lifecycle_state IN ('DRAFT','DUE_DILIGENCE','IPS_CHECK','COMPLIANCE_REVIEW','APPROVED','EXECUTED','MONITORED','CLOSED','REJECTED')),
  ips_compatible boolean,
  conflict_review_state text NOT NULL DEFAULT 'PENDING' CHECK (conflict_review_state IN ('PENDING','CLEARED','ESCALATED','BLOCKED')),
  external_transaction_reference text,
  evidence_reference text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.hei_endowment_account_links (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  endowment_pool_id bigint NOT NULL REFERENCES public.hei_endowment_pools(id),
  external_account_reference text NOT NULL,
  external_custody_reference text,
  link_role text NOT NULL CHECK (link_role IN ('PRIMARY_CUSTODY','OPERATING_CASH','INVESTMENT_ACCOUNT','SUBCUSTODY','REFERENCE_ONLY')),
  status text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','VERIFIED','ACTIVE','SUSPENDED','CLOSED')),
  evidence_reference text,
  UNIQUE (endowment_pool_id, external_account_reference, link_role)
);

CREATE OR REPLACE FUNCTION public.hei_validate_investment_decision()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  auth_status text;
  ips_status text;
  pool_status text;
BEGIN
  SELECT status INTO auth_status FROM public.hei_fiduciary_authorities WHERE id = NEW.decision_authority_id;
  SELECT status INTO ips_status FROM public.hei_investment_policy_statements WHERE id = NEW.ips_id;
  SELECT status INTO pool_status FROM public.hei_endowment_pools WHERE id = NEW.endowment_pool_id;

  IF NEW.lifecycle_state IN ('APPROVED','EXECUTED','MONITORED','CLOSED') THEN
    IF auth_status <> 'ACTIVE' THEN RAISE EXCEPTION 'active fiduciary authority required'; END IF;
    IF ips_status <> 'APPROVED' THEN RAISE EXCEPTION 'approved IPS required'; END IF;
    IF pool_status <> 'ACTIVE' THEN RAISE EXCEPTION 'active endowment pool required'; END IF;
    IF NEW.ips_compatible IS DISTINCT FROM true THEN RAISE EXCEPTION 'IPS compatibility required'; END IF;
    IF NEW.conflict_review_state <> 'CLEARED' THEN RAISE EXCEPTION 'cleared conflict review required'; END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER hei_investment_decision_gate
BEFORE INSERT OR UPDATE ON public.hei_investment_decisions
FOR EACH ROW EXECUTE FUNCTION public.hei_validate_investment_decision();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'hei_fiduciary_authorities','hei_endowment_pools','hei_investment_policy_statements',
    'hei_fund_restrictions','hei_spending_policies','hei_investment_mandates',
    'hei_strategic_allocations','hei_investment_decisions','hei_endowment_account_links'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)', t || '_service_role_all', t);
  END LOOP;
END $$;

COMMENT ON TABLE public.hei_endowment_pools IS 'Institution-controlled endowment/fund pools. Consortium/platform membership does not transfer ownership.';
COMMENT ON COLUMN public.hei_endowment_pools.endowment_cross_collateralization IS 'Hard firewall control; false by default. Separate governed authorization is required before any change.';
COMMENT ON TABLE public.hei_endowment_account_links IS 'References external custody/account systems without duplicating account numbers, balances, custody authority, or bank finality.';
