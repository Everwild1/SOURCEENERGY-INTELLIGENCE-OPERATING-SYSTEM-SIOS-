-- IBG-04 Treasury & Liquidity Control Plane
-- Extends IBG-02 accounts and IBG-03 payments. Internal liquidity state is not bank balance or settlement finality.
BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.liquidity_observations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), treasury_account_id uuid NOT NULL REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 asset_code text NOT NULL, observed_balance numeric(38,12) NOT NULL, available_balance numeric(38,12), restricted_balance numeric(38,12) NOT NULL DEFAULT 0,
 observation_type text NOT NULL DEFAULT 'EXTERNAL_REPORTED', source_reference text NOT NULL, evidence_reference text NOT NULL,
 observed_at timestamptz NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(), recorded_by_actor text NOT NULL,
 CONSTRAINT liquidity_observation_type_chk CHECK (observation_type IN ('EXTERNAL_REPORTED','BANK_STATEMENT','API_REPORTED','INTERNAL_DERIVED','MANUAL_VERIFIED')),
 CONSTRAINT liquidity_observation_evidence_chk CHECK (length(btrim(source_reference))>0 AND length(btrim(evidence_reference))>0),
 CONSTRAINT liquidity_observation_amounts_chk CHECK (restricted_balance >= 0)
);

CREATE TABLE IF NOT EXISTS capitalization.liquidity_reservations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reservation_reference text NOT NULL UNIQUE,
 treasury_account_id uuid NOT NULL REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 payment_instruction_id uuid REFERENCES capitalization.payment_instructions(id) ON DELETE RESTRICT,
 asset_code text NOT NULL, amount numeric(38,12) NOT NULL CHECK(amount>0), reservation_status text NOT NULL DEFAULT 'ACTIVE',
 purpose text NOT NULL, governance_reference text, reserved_by_actor text NOT NULL, reserved_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz, released_at timestamptz, released_by_actor text,
 CONSTRAINT liquidity_reservation_status_chk CHECK(reservation_status IN ('ACTIVE','CONSUMED','RELEASED','EXPIRED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS capitalization.treasury_limits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), limit_reference text NOT NULL UNIQUE,
 treasury_account_id uuid REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 institution_id uuid REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
 asset_code text, limit_type text NOT NULL, limit_amount numeric(38,12) NOT NULL CHECK(limit_amount>=0),
 limit_status text NOT NULL DEFAULT 'ACTIVE', evidence_reference text NOT NULL, effective_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz,
 approved_by_actor text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT treasury_limit_scope_chk CHECK(treasury_account_id IS NOT NULL OR institution_id IS NOT NULL),
 CONSTRAINT treasury_limit_type_chk CHECK(limit_type IN ('MINIMUM_LIQUIDITY_BUFFER','MAXIMUM_ACCOUNT_EXPOSURE','MAXIMUM_COUNTERPARTY_EXPOSURE','MAXIMUM_PAYMENT','MAXIMUM_DAILY_OUTFLOW','OTHER')),
 CONSTRAINT treasury_limit_status_chk CHECK(limit_status IN ('ACTIVE','SUSPENDED','EXPIRED','REVOKED'))
);

CREATE TABLE IF NOT EXISTS capitalization.treasury_limit_overrides (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), treasury_limit_id uuid NOT NULL REFERENCES capitalization.treasury_limits(id) ON DELETE RESTRICT,
 payment_instruction_id uuid REFERENCES capitalization.payment_instructions(id) ON DELETE RESTRICT, override_amount numeric(38,12), reason text NOT NULL,
 approval_status text NOT NULL DEFAULT 'PENDING', requested_by_actor text NOT NULL, checker_actor text, governance_reference text,
 requested_at timestamptz NOT NULL DEFAULT now(), decided_at timestamptz,
 CONSTRAINT treasury_override_status_chk CHECK(approval_status IN ('PENDING','APPROVED','REJECTED','REVOKED')),
 CONSTRAINT treasury_override_checker_chk CHECK(approval_status <> 'APPROVED' OR (checker_actor IS NOT NULL AND checker_actor <> requested_by_actor AND governance_reference IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.liquidity_forecasts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), treasury_account_id uuid NOT NULL REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 asset_code text NOT NULL, bucket_start timestamptz NOT NULL, bucket_end timestamptz NOT NULL, projected_inflows numeric(38,12) NOT NULL DEFAULT 0,
 projected_outflows numeric(38,12) NOT NULL DEFAULT 0, projected_closing_balance numeric(38,12), methodology_reference text NOT NULL,
 forecast_status text NOT NULL DEFAULT 'DRAFT', created_by_actor text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT liquidity_forecast_dates_chk CHECK(bucket_end>bucket_start), CONSTRAINT liquidity_forecast_status_chk CHECK(forecast_status IN ('DRAFT','APPROVED','SUPERSEDED','EXPIRED'))
);

CREATE TABLE IF NOT EXISTS capitalization.fx_exposures (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), treasury_account_id uuid REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 base_asset_code text NOT NULL, quote_asset_code text NOT NULL, exposure_amount numeric(38,12) NOT NULL, exposure_type text NOT NULL,
 valuation_reference text, observed_at timestamptz NOT NULL, evidence_reference text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT fx_exposure_assets_chk CHECK(base_asset_code<>quote_asset_code),
 CONSTRAINT fx_exposure_type_chk CHECK(exposure_type IN ('ASSET','LIABILITY','FORECAST_INFLOW','FORECAST_OUTFLOW','NET_POSITION'))
);

CREATE TABLE IF NOT EXISTS capitalization.treasury_state_history (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, entity_type text NOT NULL, entity_id uuid NOT NULL, event_type text NOT NULL,
 prior_record jsonb, new_record jsonb NOT NULL, changed_by_actor text, changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION capitalization.available_liquidity(p_account uuid,p_asset text)
RETURNS numeric LANGUAGE sql STABLE SET search_path=pg_catalog,capitalization AS $$
 WITH latest AS (SELECT COALESCE(available_balance,observed_balance-restricted_balance) a FROM capitalization.liquidity_observations WHERE treasury_account_id=p_account AND asset_code=p_asset ORDER BY observed_at DESC,recorded_at DESC LIMIT 1),
 reserved AS (SELECT COALESCE(sum(amount),0) r FROM capitalization.liquidity_reservations WHERE treasury_account_id=p_account AND asset_code=p_asset AND reservation_status='ACTIVE' AND (expires_at IS NULL OR expires_at>now()))
 SELECT COALESCE((SELECT a FROM latest),0)-COALESCE((SELECT r FROM reserved),0);
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_liquidity_reservation()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
DECLARE v_status text; v_ver text; v_elig text; v_available numeric; BEGIN
 IF NEW.reservation_status='ACTIVE' THEN
  SELECT account_status,verification_status,operational_eligibility INTO v_status,v_ver,v_elig FROM capitalization.treasury_accounts WHERE id=NEW.treasury_account_id FOR UPDATE;
  IF v_status IS DISTINCT FROM 'ACTIVE' OR v_ver IS DISTINCT FROM 'VERIFIED' OR v_elig IS DISTINCT FROM 'PRODUCTION_ELIGIBLE' THEN RAISE EXCEPTION 'liquidity reservation requires ACTIVE VERIFIED PRODUCTION_ELIGIBLE account' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM capitalization.account_restrictions ar WHERE ar.treasury_account_id=NEW.treasury_account_id AND ar.restriction_status='ACTIVE' AND (ar.expires_at IS NULL OR ar.expires_at>now())) THEN RAISE EXCEPTION 'restricted account cannot reserve liquidity' USING ERRCODE='23514'; END IF;
  v_available:=capitalization.available_liquidity(NEW.treasury_account_id,NEW.asset_code);
  IF TG_OP='UPDATE' AND OLD.reservation_status='ACTIVE' AND OLD.treasury_account_id=NEW.treasury_account_id AND OLD.asset_code=NEW.asset_code THEN v_available:=v_available+OLD.amount; END IF;
  IF v_available<NEW.amount THEN RAISE EXCEPTION 'insufficient unreserved liquidity: available %, requested %',v_available,NEW.amount USING ERRCODE='23514'; END IF;
 END IF; RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION capitalization.payment_funding_eligible(p_payment uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog,capitalization AS $$
DECLARE p record; BEGIN SELECT * INTO p FROM capitalization.payment_instructions WHERE id=p_payment; IF NOT FOUND THEN RETURN false; END IF;
 IF p.payment_state NOT IN ('APPROVED','READY') OR p.compliance_status<>'CLEAR' THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM capitalization.account_restrictions ar WHERE ar.treasury_account_id=p.source_treasury_account_id AND ar.restriction_status='ACTIVE' AND (ar.expires_at IS NULL OR ar.expires_at>now())) THEN RETURN false; END IF;
 RETURN EXISTS(SELECT 1 FROM capitalization.liquidity_reservations lr WHERE lr.payment_instruction_id=p.id AND lr.treasury_account_id=p.source_treasury_account_id AND lr.asset_code=p.asset_code AND lr.reservation_status='ACTIVE' AND lr.amount>=p.amount AND (lr.expires_at IS NULL OR lr.expires_at>now())); END; $$;

CREATE TRIGGER capitalization_liquidity_reservation_validation BEFORE INSERT OR UPDATE ON capitalization.liquidity_reservations FOR EACH ROW EXECUTE FUNCTION capitalization.validate_liquidity_reservation();
CREATE TRIGGER capitalization_treasury_history_append_only BEFORE UPDATE OR DELETE ON capitalization.treasury_state_history FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['liquidity_observations','liquidity_reservations','treasury_limits','treasury_limit_overrides','liquidity_forecasts','fx_exposures','treasury_state_history'] LOOP EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('REVOKE ALL ON capitalization.%I FROM PUBLIC, anon, authenticated',t); EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.%I TO service_role',t); END LOOP; END $$;
REVOKE UPDATE,DELETE ON capitalization.treasury_state_history FROM service_role;

CREATE OR REPLACE VIEW capitalization_api.treasury_liquidity AS
SELECT ta.account_reference,lo.asset_code,lo.observed_at,lo.observation_type,lo.observed_balance,
 capitalization.available_liquidity(ta.id,lo.asset_code) AS internally_unreserved_liquidity,
 'Internal treasury projection. Values require source evidence and do not independently prove bank balance, legal title, withdrawability, custody finality, or settlement finality.'::text disclosure
FROM capitalization.treasury_accounts ta JOIN LATERAL (SELECT x.* FROM capitalization.liquidity_observations x WHERE x.treasury_account_id=ta.id ORDER BY x.observed_at DESC,x.recorded_at DESC LIMIT 1) lo ON true;
REVOKE ALL ON capitalization_api.treasury_liquidity FROM PUBLIC,anon; GRANT SELECT ON capitalization_api.treasury_liquidity TO authenticated,service_role;

COMMENT ON FUNCTION capitalization.payment_funding_eligible(uuid) IS 'IBG-04 fail-closed funding check; does not authorize payment execution or settlement.';
COMMENT ON TABLE capitalization.fx_exposures IS 'FX risk metadata only. Presence of exposure records confers no FX trading or market execution authority.';
COMMIT;
