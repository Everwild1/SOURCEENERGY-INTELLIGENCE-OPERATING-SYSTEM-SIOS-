-- TST-WP03/WP04 stewardship ledger foundation.
-- Exact numeric money, server-derived tithe calculations, restricted funds and allocations.

CREATE TABLE tst.funds (
 fund_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 fund_code text NOT NULL,
 fund_name text NOT NULL,
 restriction_type text NOT NULL CHECK (restriction_type IN ('UNRESTRICTED','BOARD_DESIGNATED','DONOR_RESTRICTED','PURPOSE_RESTRICTED')),
 currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
 status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(stewardship_entity_id,fund_code)
);

CREATE TABLE tst.tithe_elections (
 election_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
 organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
 rate numeric(9,6) NOT NULL CHECK (rate > 0 AND rate <= 1),
 basis_code text NOT NULL,
 currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
 status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
 effective_from date NOT NULL,
 effective_to date,
 approval_reference text,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE UNIQUE INDEX tst_one_open_active_election_idx ON tst.tithe_elections(stewardship_entity_id,organization_oid,basis_code)
 WHERE status='ACTIVE' AND effective_to IS NULL;

CREATE TABLE tst.tithe_calculations (
 calculation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 election_id uuid NOT NULL REFERENCES tst.tithe_elections(election_id) ON DELETE RESTRICT,
 period_start date NOT NULL,
 period_end date NOT NULL,
 eligible_base numeric(24,6) NOT NULL CHECK (eligible_base >= 0),
 applied_rate numeric(9,6) NOT NULL CHECK (applied_rate > 0 AND applied_rate <= 1),
 calculated_amount numeric(24,6) NOT NULL CHECK (calculated_amount >= 0),
 currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
 status text NOT NULL DEFAULT 'CALCULATED' CHECK (status IN ('CALCULATED','APPROVED','VOID')),
 calculation_method text NOT NULL DEFAULT 'SERVER_ELECTION_RATE',
 created_at timestamptz NOT NULL DEFAULT now(),
 approved_at timestamptz,
 CHECK (period_end >= period_start),
 UNIQUE(election_id,period_start,period_end)
);

CREATE TABLE tst.contributions (
 contribution_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 calculation_id uuid NOT NULL REFERENCES tst.tithe_calculations(calculation_id) ON DELETE RESTRICT,
 fund_id uuid NOT NULL REFERENCES tst.funds(fund_id) ON DELETE RESTRICT,
 amount numeric(24,6) NOT NULL CHECK (amount > 0),
 currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
 received_at timestamptz,
 external_reference text,
 status text NOT NULL DEFAULT 'EXPECTED' CHECK (status IN ('EXPECTED','RECEIVED','RECONCILED','REVERSED')),
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tst.allocations (
 allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 fund_id uuid NOT NULL REFERENCES tst.funds(fund_id) ON DELETE RESTRICT,
 allocation_code text NOT NULL,
 purpose text NOT NULL,
 authorized_amount numeric(24,6) NOT NULL CHECK (authorized_amount > 0),
 committed_amount numeric(24,6) NOT NULL DEFAULT 0 CHECK (committed_amount >= 0),
 disbursed_amount numeric(24,6) NOT NULL DEFAULT 0 CHECK (disbursed_amount >= 0),
 currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
 status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','CLOSED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (committed_amount <= authorized_amount),
 CHECK (disbursed_amount <= committed_amount),
 UNIQUE(fund_id,allocation_code)
);

CREATE OR REPLACE FUNCTION tst_private.calculate_tithe(
 p_election_id uuid, p_period_start date, p_period_end date, p_eligible_base numeric
) RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private,public AS $$
DECLARE e tst.tithe_elections%ROWTYPE; cid uuid;
BEGIN
 IF p_eligible_base < 0 OR p_period_end < p_period_start THEN RAISE EXCEPTION 'invalid calculation input'; END IF;
 SELECT * INTO e FROM tst.tithe_elections WHERE election_id=p_election_id AND status='ACTIVE'
   AND effective_from <= p_period_end AND (effective_to IS NULL OR effective_to >= p_period_start);
 IF NOT FOUND THEN RAISE EXCEPTION 'no active election for period'; END IF;
 INSERT INTO tst.tithe_calculations(election_id,period_start,period_end,eligible_base,applied_rate,calculated_amount,currency)
 VALUES(e.election_id,p_period_start,p_period_end,p_eligible_base,e.rate,round(p_eligible_base*e.rate,6),e.currency)
 RETURNING calculation_id INTO cid;
 RETURN cid;
END $$;

CREATE OR REPLACE FUNCTION tst_private.fund_available_balance(p_fund_id uuid)
RETURNS numeric LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
 SELECT COALESCE((SELECT sum(amount) FROM tst.contributions WHERE fund_id=p_fund_id AND status IN ('RECEIVED','RECONCILED')),0)
      - COALESCE((SELECT sum(committed_amount) FROM tst.allocations WHERE fund_id=p_fund_id AND status IN ('ACTIVE','SUSPENDED')),0);
$$;

CREATE OR REPLACE FUNCTION tst_private.enforce_allocation_capacity() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE available numeric;
BEGIN
 SELECT tst_private.fund_available_balance(NEW.fund_id) INTO available;
 IF TG_OP='UPDATE' THEN available := available + OLD.committed_amount; END IF;
 IF NEW.committed_amount > available THEN RAISE EXCEPTION 'allocation commitment exceeds available fund balance'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tst_allocation_capacity BEFORE INSERT OR UPDATE OF committed_amount,fund_id ON tst.allocations
FOR EACH ROW EXECUTE FUNCTION tst_private.enforce_allocation_capacity();

CREATE INDEX tst_elections_scope_idx ON tst.tithe_elections(stewardship_entity_id,organization_oid,status,effective_from,effective_to);
CREATE INDEX tst_calculations_election_idx ON tst.tithe_calculations(election_id,status,period_start,period_end);
CREATE INDEX tst_contributions_fund_status_idx ON tst.contributions(fund_id,status);
CREATE INDEX tst_allocations_fund_status_idx ON tst.allocations(fund_id,status);

ALTER TABLE tst.funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.tithe_elections ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.tithe_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.allocations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tst.funds,tst.tithe_elections,tst.tithe_calculations,tst.contributions,tst.allocations FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON tst.funds,tst.tithe_elections,tst.tithe_calculations,tst.contributions,tst.allocations TO service_role;
CREATE POLICY funds_service_role_all ON tst.funds FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY elections_service_role_all ON tst.tithe_elections FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY calculations_service_role_all ON tst.tithe_calculations FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY contributions_service_role_all ON tst.contributions FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY allocations_service_role_all ON tst.allocations FOR ALL TO service_role USING(true) WITH CHECK(true);
REVOKE ALL ON FUNCTION tst_private.calculate_tithe(uuid,date,date,numeric) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.fund_available_balance(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION tst_private.calculate_tithe(uuid,date,date,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.fund_available_balance(uuid) TO service_role;
