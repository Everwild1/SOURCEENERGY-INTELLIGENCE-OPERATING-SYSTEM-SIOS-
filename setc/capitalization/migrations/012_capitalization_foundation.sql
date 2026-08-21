-- SourceEnergy Capitalization Block / Empire Block foundation.
-- Internal financial control-plane schema. This migration creates software and
-- data controls only; it does not create banking, custody, regulatory, or
-- settlement authority.

BEGIN;

CREATE SCHEMA IF NOT EXISTS capitalization;
CREATE SCHEMA IF NOT EXISTS capitalization_api;

COMMENT ON SCHEMA capitalization IS
'Internal Capitalization Block authority for capital lineage, treasury orchestration, interbank relationship state, fiat settlement orchestration, reconciliation, and evidence. Not a banking charter, custody authority, or external settlement rail.';

COMMENT ON SCHEMA capitalization_api IS
'Deliberately narrow, public-safe Capitalization Block projection. Internal financial records must never be exposed through this schema.';

REVOKE ALL ON SCHEMA capitalization FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA capitalization TO service_role;

REVOKE ALL ON SCHEMA capitalization_api FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA capitalization_api TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA capitalization
    REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA capitalization
    REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA capitalization
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION capitalization.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.prevent_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    RAISE EXCEPTION 'destructive deletion is prohibited for %.%; use governed state transitions or compensating records',
        TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '55000';
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.prevent_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    RAISE EXCEPTION '%.% is append-only; update/delete mutation is prohibited',
        TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '55000';
END;
$$;

CREATE SEQUENCE IF NOT EXISTS capitalization.ecid_sequence
    AS bigint
    START WITH 1
    INCREMENT BY 1
    NO CYCLE;

CREATE OR REPLACE FUNCTION capitalization.next_ecid(
    p_year integer DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::integer
)
RETURNS text
LANGUAGE sql
VOLATILE
SET search_path = pg_catalog, capitalization
AS $$
    SELECT format(
        'ECID-%s-%s',
        p_year,
        lpad(nextval('capitalization.ecid_sequence')::text, 9, '0')
    );
$$;

CREATE TABLE IF NOT EXISTS capitalization.release_gates (
    gate_code text PRIMARY KEY,
    enabled boolean NOT NULL DEFAULT false,
    authorization_reference text,
    evidence_reference text,
    authorized_by_actor text,
    authorized_at timestamptz,
    rationale text,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_release_gates_code_chk CHECK (
        gate_code IN ('PRODUCTION_SETTLEMENT', 'PUBLIC_LIVE_NETWORK_CLAIMS')
    ),
    CONSTRAINT capitalization_release_gates_enablement_evidence_chk CHECK (
        enabled = false OR (
            authorization_reference IS NOT NULL
            AND length(btrim(authorization_reference)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND authorized_by_actor IS NOT NULL
            AND length(btrim(authorized_by_actor)) > 0
            AND authorized_at IS NOT NULL
            AND rationale IS NOT NULL
            AND length(btrim(rationale)) > 0
        )
    )
);

INSERT INTO capitalization.release_gates (gate_code, enabled, rationale)
VALUES
    ('PRODUCTION_SETTLEMENT', false, 'NO-GO until independently evidenced governance authorization'),
    ('PUBLIC_LIVE_NETWORK_CLAIMS', false, 'NO-GO until relationship and production-connectivity claims are independently verified')
ON CONFLICT (gate_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS capitalization.capital_sources (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_reference text NOT NULL UNIQUE,
    setc_organization_id text,
    legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
    display_name text,
    source_type text NOT NULL,
    jurisdiction_code text,
    verification_status text NOT NULL DEFAULT 'UNVERIFIED',
    operating_status text NOT NULL DEFAULT 'PROSPECTIVE',
    evidence_reference text,
    provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_capital_sources_setc_id_chk CHECK (
        setc_organization_id IS NULL
        OR setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_capital_sources_type_chk CHECK (
        source_type IN (
            'INTERNAL_TREASURY', 'RESERVE', 'FAMILY_OFFICE', 'FOUNDATION',
            'INSTITUTIONAL_INVESTOR', 'DEVELOPMENT_FINANCE', 'SOVEREIGN_PUBLIC',
            'BANK_FACILITY', 'GRANT', 'DONOR', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_capital_sources_verification_chk CHECK (
        verification_status IN (
            'UNVERIFIED', 'PENDING', 'VERIFIED', 'RESTRICTED', 'SUSPENDED'
        )
    ),
    CONSTRAINT capitalization_capital_sources_status_chk CHECK (
        operating_status IN (
            'PROSPECTIVE', 'DUE_DILIGENCE', 'APPROVED', 'ACTIVE',
            'RESTRICTED', 'SUSPENDED', 'CLOSED'
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.capital_commitments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ecid text NOT NULL UNIQUE DEFAULT capitalization.next_ecid(),
    source_id uuid NOT NULL REFERENCES capitalization.capital_sources(id) ON DELETE RESTRICT,
    recipient_setc_organization_id text,
    commitment_reference text NOT NULL UNIQUE,
    commitment_type text NOT NULL,
    asset_code text NOT NULL,
    asset_class text NOT NULL DEFAULT 'FIAT',
    committed_amount numeric(38, 12) NOT NULL CHECK (committed_amount > 0),
    available_amount numeric(38, 12) NOT NULL DEFAULT 0 CHECK (available_amount >= 0),
    restricted_amount numeric(38, 12) NOT NULL DEFAULT 0 CHECK (restricted_amount >= 0),
    commitment_state text NOT NULL DEFAULT 'DRAFT',
    agreement_reference text,
    evidence_reference text,
    restrictions jsonb NOT NULL DEFAULT '[]'::jsonb,
    effective_at timestamptz,
    expires_at timestamptz,
    provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_commitments_ecid_chk CHECK (
        ecid ~ '^ECID-[0-9]{4}-[0-9]{9}$'
    ),
    CONSTRAINT capitalization_commitments_recipient_chk CHECK (
        recipient_setc_organization_id IS NULL
        OR recipient_setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_commitments_type_chk CHECK (
        commitment_type IN (
            'EQUITY', 'DEBT', 'GRANT', 'GUARANTEE', 'LETTER_OF_CREDIT',
            'CREDIT_FACILITY', 'RESERVE_CONTRIBUTION', 'PROGRAM_ALLOCATION',
            'DONATION', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_commitments_asset_code_chk CHECK (
        asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'
    ),
    CONSTRAINT capitalization_commitments_asset_class_chk CHECK (
        asset_class IN ('FIAT', 'DIGITAL_ASSET', 'SECURITY', 'COMMODITY', 'OTHER')
    ),
    CONSTRAINT capitalization_commitments_state_chk CHECK (
        commitment_state IN (
            'DRAFT', 'UNDER_REVIEW', 'APPROVED', 'COMMITTED', 'ACTIVE',
            'FULLY_ALLOCATED', 'EXPIRED', 'CANCELLED', 'RESTRICTED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_commitments_balance_chk CHECK (
        available_amount + restricted_amount <= committed_amount
    ),
    CONSTRAINT capitalization_commitments_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    ),
    CONSTRAINT capitalization_commitments_evidence_chk CHECK (
        commitment_state NOT IN ('COMMITTED', 'ACTIVE', 'FULLY_ALLOCATED', 'CLOSED')
        OR (
            agreement_reference IS NOT NULL
            AND length(btrim(agreement_reference)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.capital_facilities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_reference text NOT NULL UNIQUE,
    commitment_id uuid NOT NULL REFERENCES capitalization.capital_commitments(id) ON DELETE RESTRICT,
    facility_type text NOT NULL,
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    approved_amount numeric(38, 12) NOT NULL CHECK (approved_amount > 0),
    available_amount numeric(38, 12) NOT NULL DEFAULT 0 CHECK (available_amount >= 0),
    restricted_amount numeric(38, 12) NOT NULL DEFAULT 0 CHECK (restricted_amount >= 0),
    facility_state text NOT NULL DEFAULT 'DRAFT',
    governing_terms jsonb NOT NULL DEFAULT '{}'::jsonb,
    evidence_reference text,
    effective_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_facilities_type_chk CHECK (
        facility_type IN (
            'REVOLVING', 'TERM', 'PROJECT_FINANCE', 'TRADE_FINANCE',
            'GUARANTEE', 'GRANT_PROGRAM', 'RESERVE', 'INVESTMENT', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_facilities_state_chk CHECK (
        facility_state IN (
            'DRAFT', 'UNDER_REVIEW', 'APPROVED', 'ACTIVE', 'FULLY_DRAWN',
            'EXPIRED', 'RESTRICTED', 'SUSPENDED', 'CLOSED', 'CANCELLED'
        )
    ),
    CONSTRAINT capitalization_facilities_balance_chk CHECK (
        available_amount + restricted_amount <= approved_amount
    ),
    CONSTRAINT capitalization_facilities_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    ),
    CONSTRAINT capitalization_facilities_evidence_chk CHECK (
        facility_state NOT IN ('APPROVED', 'ACTIVE', 'FULLY_DRAWN', 'CLOSED')
        OR (evidence_reference IS NOT NULL AND length(btrim(evidence_reference)) > 0)
    )
);

CREATE TABLE IF NOT EXISTS capitalization.capital_allocations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    allocation_reference text NOT NULL UNIQUE,
    commitment_id uuid NOT NULL REFERENCES capitalization.capital_commitments(id) ON DELETE RESTRICT,
    facility_id uuid REFERENCES capitalization.capital_facilities(id) ON DELETE RESTRICT,
    destination_type text NOT NULL,
    destination_reference text NOT NULL CHECK (length(btrim(destination_reference)) > 0),
    amount numeric(38, 12) NOT NULL CHECK (amount > 0),
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    allocation_state text NOT NULL DEFAULT 'DRAFT',
    approval_reference text,
    evidence_reference text,
    restrictions jsonb NOT NULL DEFAULT '[]'::jsonb,
    approved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_allocations_destination_chk CHECK (
        destination_type IN (
            'PROJECT', 'PROGRAM', 'ORGANIZATION', 'WIM_OPPORTUNITY',
            'WIM_TRANSACTION', 'RESERVE_POOL', 'TREASURY_ACCOUNT', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_allocations_state_chk CHECK (
        allocation_state IN (
            'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'RESERVED', 'DEPLOYING',
            'DEPLOYED', 'RECONCILED', 'RESTRICTED', 'CANCELLED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_allocations_evidence_chk CHECK (
        allocation_state NOT IN ('APPROVED', 'RESERVED', 'DEPLOYING', 'DEPLOYED', 'RECONCILED', 'CLOSED')
        OR (
            approval_reference IS NOT NULL
            AND length(btrim(approval_reference)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND approved_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.capital_deployments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    deployment_reference text NOT NULL UNIQUE,
    allocation_id uuid NOT NULL REFERENCES capitalization.capital_allocations(id) ON DELETE RESTRICT,
    destination_type text NOT NULL,
    destination_reference text NOT NULL CHECK (length(btrim(destination_reference)) > 0),
    wim_transaction_id uuid,
    wim_commercialization_project_id uuid,
    destination_setc_organization_id text,
    amount numeric(38, 12) NOT NULL CHECK (amount > 0),
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    deployment_state text NOT NULL DEFAULT 'PLANNED',
    settlement_instruction_reference text,
    evidence_reference text,
    deployed_at timestamptz,
    reconciled_at timestamptz,
    outcomes_reference text,
    provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_deployments_destination_chk CHECK (
        destination_type IN (
            'PROJECT', 'PROGRAM', 'ORGANIZATION', 'WIM_TRANSACTION',
            'WIM_COMMERCIALIZATION_PROJECT', 'ASSET', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_deployments_setc_id_chk CHECK (
        destination_setc_organization_id IS NULL
        OR destination_setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_deployments_state_chk CHECK (
        deployment_state IN (
            'PLANNED', 'PENDING_APPROVAL', 'APPROVED', 'IN_FLIGHT',
            'DEPLOYED', 'RECONCILED', 'EXCEPTION', 'RESTRICTED',
            'CANCELLED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_deployments_evidence_chk CHECK (
        deployment_state NOT IN ('DEPLOYED', 'RECONCILED', 'CLOSED')
        OR (
            settlement_instruction_reference IS NOT NULL
            AND length(btrim(settlement_instruction_reference)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND deployed_at IS NOT NULL
        )
    ),
    CONSTRAINT capitalization_deployments_reconciled_chk CHECK (
        deployment_state <> 'RECONCILED' OR reconciled_at IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS capitalization.capital_lineage_events (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ecid text NOT NULL CHECK (ecid ~ '^ECID-[0-9]{4}-[0-9]{9}$'),
    object_type text NOT NULL,
    object_reference text NOT NULL CHECK (length(btrim(object_reference)) > 0),
    event_type text NOT NULL CHECK (length(btrim(event_type)) > 0),
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    evidence_reference text,
    actor_reference text,
    correlation_id text,
    causation_id text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_lineage_object_type_chk CHECK (
        object_type IN (
            'CAPITAL_SOURCE', 'COMMITMENT', 'FACILITY', 'ALLOCATION',
            'TREASURY_ACCOUNT', 'RESERVE_POOL', 'SETTLEMENT',
            'DEPLOYMENT', 'RECONCILIATION', 'OUTCOME', 'OTHER'
        )
    )
);

CREATE INDEX IF NOT EXISTS capitalization_capital_sources_setc_idx
    ON capitalization.capital_sources (setc_organization_id);
CREATE INDEX IF NOT EXISTS capitalization_commitments_source_state_idx
    ON capitalization.capital_commitments (source_id, commitment_state);
CREATE INDEX IF NOT EXISTS capitalization_commitments_ecid_state_idx
    ON capitalization.capital_commitments (ecid, commitment_state);
CREATE INDEX IF NOT EXISTS capitalization_facilities_commitment_state_idx
    ON capitalization.capital_facilities (commitment_id, facility_state);
CREATE INDEX IF NOT EXISTS capitalization_allocations_commitment_state_idx
    ON capitalization.capital_allocations (commitment_id, allocation_state);
CREATE INDEX IF NOT EXISTS capitalization_allocations_destination_idx
    ON capitalization.capital_allocations (destination_type, destination_reference);
CREATE INDEX IF NOT EXISTS capitalization_deployments_allocation_state_idx
    ON capitalization.capital_deployments (allocation_id, deployment_state);
CREATE INDEX IF NOT EXISTS capitalization_lineage_ecid_time_idx
    ON capitalization.capital_lineage_events (ecid, occurred_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_lineage_correlation_idx
    ON capitalization.capital_lineage_events (correlation_id)
    WHERE correlation_id IS NOT NULL;

DROP TRIGGER IF EXISTS capitalization_release_gates_updated_at
    ON capitalization.release_gates;
CREATE TRIGGER capitalization_release_gates_updated_at
BEFORE UPDATE ON capitalization.release_gates
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_sources_updated_at
    ON capitalization.capital_sources;
CREATE TRIGGER capitalization_capital_sources_updated_at
BEFORE UPDATE ON capitalization.capital_sources
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_commitments_updated_at
    ON capitalization.capital_commitments;
CREATE TRIGGER capitalization_capital_commitments_updated_at
BEFORE UPDATE ON capitalization.capital_commitments
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_facilities_updated_at
    ON capitalization.capital_facilities;
CREATE TRIGGER capitalization_capital_facilities_updated_at
BEFORE UPDATE ON capitalization.capital_facilities
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_allocations_updated_at
    ON capitalization.capital_allocations;
CREATE TRIGGER capitalization_capital_allocations_updated_at
BEFORE UPDATE ON capitalization.capital_allocations
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_deployments_updated_at
    ON capitalization.capital_deployments;
CREATE TRIGGER capitalization_capital_deployments_updated_at
BEFORE UPDATE ON capitalization.capital_deployments
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_capital_sources_no_delete
    ON capitalization.capital_sources;
CREATE TRIGGER capitalization_capital_sources_no_delete
BEFORE DELETE ON capitalization.capital_sources
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete();

DROP TRIGGER IF EXISTS capitalization_capital_commitments_no_delete
    ON capitalization.capital_commitments;
CREATE TRIGGER capitalization_capital_commitments_no_delete
BEFORE DELETE ON capitalization.capital_commitments
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete();

DROP TRIGGER IF EXISTS capitalization_capital_facilities_no_delete
    ON capitalization.capital_facilities;
CREATE TRIGGER capitalization_capital_facilities_no_delete
BEFORE DELETE ON capitalization.capital_facilities
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete();

DROP TRIGGER IF EXISTS capitalization_capital_allocations_no_delete
    ON capitalization.capital_allocations;
CREATE TRIGGER capitalization_capital_allocations_no_delete
BEFORE DELETE ON capitalization.capital_allocations
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete();

DROP TRIGGER IF EXISTS capitalization_capital_deployments_no_delete
    ON capitalization.capital_deployments;
CREATE TRIGGER capitalization_capital_deployments_no_delete
BEFORE DELETE ON capitalization.capital_deployments
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete();

DROP TRIGGER IF EXISTS capitalization_lineage_events_append_only
    ON capitalization.capital_lineage_events;
CREATE TRIGGER capitalization_lineage_events_append_only
BEFORE UPDATE OR DELETE ON capitalization.capital_lineage_events
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

ALTER TABLE capitalization.release_gates ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_deployments ENABLE ROW LEVEL SECURITY;
ALTER TABLE capitalization.capital_lineage_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA capitalization TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA capitalization TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization TO service_role;

COMMENT ON TABLE capitalization.release_gates IS
'Explicit NO-GO/GO control records. Enabling a gate requires accountable authorization and evidence; infrastructure readiness alone is insufficient.';
COMMENT ON TABLE capitalization.capital_commitments IS
'Canonical capital commitments identified by ECID. A record does not prove funds, title, custody, or legal enforceability without external evidence.';
COMMENT ON TABLE capitalization.capital_lineage_events IS
'Append-only capital lineage evidence. Events provide traceability and do not independently create economic or legal authority.';

COMMIT;
