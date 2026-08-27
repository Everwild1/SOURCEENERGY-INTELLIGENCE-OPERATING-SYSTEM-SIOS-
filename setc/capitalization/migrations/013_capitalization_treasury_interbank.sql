-- SourceEnergy Capitalization Block treasury and interbank registry.
-- Relationship, connectivity, and verification are independent dimensions.
-- Internal identifiers never substitute for external bank identifiers.

BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.financial_institutions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_reference text NOT NULL UNIQUE,
    setc_organization_id text,
    wim_organization_id uuid,
    legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
    display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
    institution_type text NOT NULL,
    jurisdiction_code text,
    region_code text,
    website_url text,
    verification_status text NOT NULL DEFAULT 'UNVERIFIED',
    operating_status text NOT NULL DEFAULT 'PROSPECTIVE',
    regulatory_evidence_reference text,
    verification_evidence_reference text,
    last_verified_at timestamptz,
    public_display_enabled boolean NOT NULL DEFAULT false,
    provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_financial_institutions_setc_id_chk CHECK (
        setc_organization_id IS NULL
        OR setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_financial_institutions_type_chk CHECK (
        institution_type IN (
            'COMMERCIAL_BANK', 'CENTRAL_BANK', 'DEVELOPMENT_BANK', 'EXIM_BANK',
            'CREDIT_UNION', 'CUSTODIAN', 'DIGITAL_ASSET_CUSTODIAN',
            'PAYMENT_NETWORK', 'SETTLEMENT_PROVIDER',
            'FINANCIAL_MARKET_INFRASTRUCTURE', 'FINTECH_INFRASTRUCTURE',
            'SOVEREIGN_NODE', 'TREASURY_ENTITY', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_financial_institutions_verification_chk CHECK (
        verification_status IN (
            'UNVERIFIED', 'PENDING', 'VERIFIED', 'RESTRICTED', 'SUSPENDED'
        )
    ),
    CONSTRAINT capitalization_financial_institutions_status_chk CHECK (
        operating_status IN (
            'PROSPECTIVE', 'DUE_DILIGENCE', 'APPROVED', 'ACTIVE',
            'RESTRICTED', 'SUSPENDED', 'INACTIVE', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_financial_institutions_verified_evidence_chk CHECK (
        verification_status <> 'VERIFIED'
        OR (
            verification_evidence_reference IS NOT NULL
            AND length(btrim(verification_evidence_reference)) > 0
            AND last_verified_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.institution_relationships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id uuid NOT NULL UNIQUE
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    relationship_state text NOT NULL DEFAULT 'TARGET',
    relationship_purpose text NOT NULL DEFAULT 'INTERBANK_NETWORK',
    agreement_reference text,
    evidence_reference text,
    effective_at timestamptz,
    expires_at timestamptz,
    last_verified_at timestamptz,
    status_reason text,
    asserted_by_actor text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_relationships_state_chk CHECK (
        relationship_state IN (
            'TARGET', 'IDENTIFIED', 'CONTACTED', 'DUE_DILIGENCE', 'QUALIFIED',
            'AGREEMENT_PENDING', 'CONTRACTED', 'INTEGRATION_PENDING',
            'INTEGRATED', 'LIVE', 'SUSPENDED', 'TERMINATED'
        )
    ),
    CONSTRAINT capitalization_relationships_purpose_chk CHECK (
        relationship_purpose IN (
            'INTERBANK_NETWORK', 'TREASURY', 'CUSTODY', 'PAYMENT_RAIL',
            'SETTLEMENT', 'LIQUIDITY', 'TRADE_FINANCE', 'DIGITAL_ASSET', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_relationships_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    ),
    CONSTRAINT capitalization_relationships_evidence_chk CHECK (
        relationship_state NOT IN (
            'CONTRACTED', 'INTEGRATION_PENDING', 'INTEGRATED', 'LIVE'
        )
        OR (
            evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND last_verified_at IS NOT NULL
        )
    ),
    CONSTRAINT capitalization_relationships_agreement_chk CHECK (
        relationship_state NOT IN (
            'CONTRACTED', 'INTEGRATION_PENDING', 'INTEGRATED', 'LIVE'
        )
        OR (
            agreement_reference IS NOT NULL
            AND length(btrim(agreement_reference)) > 0
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.network_nodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id uuid NOT NULL
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    sourceenergy_node_id text NOT NULL UNIQUE,
    dominion_cube_id text UNIQUE,
    relay_code text UNIQUE,
    layer_number integer CHECK (layer_number IS NULL OR layer_number BETWEEN 1 AND 99),
    node_type text NOT NULL,
    operational_role text,
    environment text NOT NULL DEFAULT 'PLANNED',
    connectivity_status text NOT NULL DEFAULT 'NOT_CONNECTED',
    node_status text NOT NULL DEFAULT 'INACTIVE',
    endpoint_reference text,
    evidence_reference text,
    last_verified_at timestamptz,
    public_display_enabled boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_network_nodes_type_chk CHECK (
        node_type IN (
            'BANK', 'TREASURY', 'CUSTODY', 'PAYMENT', 'SETTLEMENT',
            'LIQUIDITY', 'DIGITAL_ASSET', 'SOVEREIGN', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_network_nodes_environment_chk CHECK (
        environment IN ('PLANNED', 'SANDBOX', 'TEST', 'CERTIFICATION', 'PRODUCTION')
    ),
    CONSTRAINT capitalization_network_nodes_connectivity_chk CHECK (
        connectivity_status IN (
            'NOT_CONNECTED', 'SANDBOX', 'TEST', 'CERTIFICATION',
            'PRODUCTION', 'DEGRADED', 'OFFLINE'
        )
    ),
    CONSTRAINT capitalization_network_nodes_status_chk CHECK (
        node_status IN (
            'INACTIVE', 'PENDING', 'ACTIVE', 'RESTRICTED', 'SUSPENDED', 'RETIRED'
        )
    ),
    CONSTRAINT capitalization_network_nodes_internal_id_chk CHECK (
        dominion_cube_id IS NULL OR dominion_cube_id ~ '^L[0-9]+-[A-Z0-9-]+$'
    ),
    CONSTRAINT capitalization_network_nodes_relay_chk CHECK (
        relay_code IS NULL OR relay_code ~ '^WK-[A-Z0-9-]+$'
    ),
    CONSTRAINT capitalization_network_nodes_production_chk CHECK (
        connectivity_status <> 'PRODUCTION'
        OR (
            environment = 'PRODUCTION'
            AND node_status = 'ACTIVE'
            AND endpoint_reference IS NOT NULL
            AND length(btrim(endpoint_reference)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND last_verified_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.institution_external_identifiers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id uuid NOT NULL
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    identifier_type text NOT NULL,
    identifier_value text NOT NULL CHECK (length(btrim(identifier_value)) > 0),
    identifier_authority text,
    sensitivity_class text NOT NULL DEFAULT 'INTERNAL',
    verification_status text NOT NULL DEFAULT 'UNVERIFIED',
    evidence_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (identifier_type, identifier_value),
    CONSTRAINT capitalization_external_ids_type_chk CHECK (
        identifier_type IN (
            'LEI', 'SWIFT_BIC', 'ROUTING_IDENTIFIER', 'CLEARING_IDENTIFIER',
            'IBAN_MASKED', 'PROVIDER_IDENTIFIER', 'LICENSE_IDENTIFIER', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_external_ids_sensitivity_chk CHECK (
        sensitivity_class IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED')
    ),
    CONSTRAINT capitalization_external_ids_verification_chk CHECK (
        verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'RESTRICTED')
    ),
    CONSTRAINT capitalization_external_ids_verified_evidence_chk CHECK (
        verification_status <> 'VERIFIED'
        OR (evidence_reference IS NOT NULL AND length(btrim(evidence_reference)) > 0)
    )
);

CREATE TABLE IF NOT EXISTS capitalization.integration_endpoints (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    node_id uuid NOT NULL REFERENCES capitalization.network_nodes(id) ON DELETE RESTRICT,
    endpoint_reference text NOT NULL UNIQUE,
    endpoint_type text NOT NULL,
    environment text NOT NULL DEFAULT 'SANDBOX',
    base_url text,
    credential_reference text,
    certificate_reference text,
    connectivity_status text NOT NULL DEFAULT 'NOT_CONNECTED',
    evidence_reference text,
    last_verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_integration_endpoints_type_chk CHECK (
        endpoint_type IN (
            'API', 'SFTP', 'SWIFT_INTERFACE', 'PAYMENT_NETWORK',
            'WEBHOOK', 'MESSAGE_BUS', 'MANUAL', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_integration_endpoints_environment_chk CHECK (
        environment IN ('SANDBOX', 'TEST', 'CERTIFICATION', 'PRODUCTION')
    ),
    CONSTRAINT capitalization_integration_endpoints_connectivity_chk CHECK (
        connectivity_status IN (
            'NOT_CONNECTED', 'SANDBOX', 'TEST', 'CERTIFICATION',
            'PRODUCTION', 'DEGRADED', 'OFFLINE'
        )
    ),
    CONSTRAINT capitalization_integration_endpoints_credential_chk CHECK (
        credential_reference IS NULL
        OR credential_reference ~ '^(vault|secret|token|provider):[A-Za-z0-9._:/-]+$'
    ),
    CONSTRAINT capitalization_integration_endpoints_production_chk CHECK (
        connectivity_status <> 'PRODUCTION'
        OR (
            environment = 'PRODUCTION'
            AND base_url IS NOT NULL
            AND credential_reference IS NOT NULL
            AND certificate_reference IS NOT NULL
            AND evidence_reference IS NOT NULL
            AND last_verified_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.interbank_corridors (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    corridor_reference text NOT NULL UNIQUE,
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    origin_jurisdiction_code text,
    destination_jurisdiction_code text,
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    rail_type text NOT NULL,
    environment text NOT NULL DEFAULT 'PLANNED',
    corridor_status text NOT NULL DEFAULT 'PROPOSED',
    daily_limit numeric(38, 12) CHECK (daily_limit IS NULL OR daily_limit > 0),
    per_transaction_limit numeric(38, 12)
        CHECK (per_transaction_limit IS NULL OR per_transaction_limit > 0),
    governance_reference text,
    compliance_reference text,
    evidence_reference text,
    last_verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_interbank_corridors_rail_chk CHECK (
        rail_type IN (
            'FIAT_EXTERNAL', 'SOURCE_COIN', 'INTERNAL_BOOK_TRANSFER',
            'PAYMENT_NETWORK', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_interbank_corridors_environment_chk CHECK (
        environment IN ('PLANNED', 'SANDBOX', 'TEST', 'CERTIFICATION', 'PRODUCTION')
    ),
    CONSTRAINT capitalization_interbank_corridors_status_chk CHECK (
        corridor_status IN (
            'PROPOSED', 'DUE_DILIGENCE', 'SANDBOX', 'TEST', 'CERTIFICATION',
            'PRODUCTION', 'RESTRICTED', 'SUSPENDED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_interbank_corridors_limit_chk CHECK (
        daily_limit IS NULL OR per_transaction_limit IS NULL
        OR per_transaction_limit <= daily_limit
    ),
    CONSTRAINT capitalization_interbank_corridors_production_chk CHECK (
        corridor_status <> 'PRODUCTION'
        OR (
            environment = 'PRODUCTION'
            AND governance_reference IS NOT NULL
            AND compliance_reference IS NOT NULL
            AND evidence_reference IS NOT NULL
            AND last_verified_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.corridor_participants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    corridor_id uuid NOT NULL
        REFERENCES capitalization.interbank_corridors(id) ON DELETE RESTRICT,
    institution_id uuid NOT NULL
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    participant_role text NOT NULL,
    participation_status text NOT NULL DEFAULT 'PROPOSED',
    evidence_reference text,
    effective_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (corridor_id, institution_id, participant_role),
    CONSTRAINT capitalization_corridor_participants_role_chk CHECK (
        participant_role IN (
            'ORIGINATOR', 'BENEFICIARY', 'CORRESPONDENT', 'CUSTODIAN',
            'LIQUIDITY_PROVIDER', 'CLEARING', 'SETTLEMENT', 'COMPLIANCE', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_corridor_participants_status_chk CHECK (
        participation_status IN (
            'PROPOSED', 'DUE_DILIGENCE', 'APPROVED', 'ACTIVE',
            'RESTRICTED', 'SUSPENDED', 'TERMINATED'
        )
    ),
    CONSTRAINT capitalization_corridor_participants_evidence_chk CHECK (
        participation_status NOT IN ('APPROVED', 'ACTIVE')
        OR (evidence_reference IS NOT NULL AND length(btrim(evidence_reference)) > 0)
    ),
    CONSTRAINT capitalization_corridor_participants_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    )
);

CREATE TABLE IF NOT EXISTS capitalization.treasury_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_reference text NOT NULL UNIQUE,
    owner_setc_organization_id text,
    custodian_institution_id uuid
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    account_type text NOT NULL,
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    external_account_reference text,
    account_status text NOT NULL DEFAULT 'PLANNED',
    reconciliation_source text,
    evidence_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_treasury_accounts_owner_chk CHECK (
        owner_setc_organization_id IS NULL
        OR owner_setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_treasury_accounts_type_chk CHECK (
        account_type IN (
            'OPERATING', 'RESERVE', 'ESCROW', 'CUSTODY', 'SETTLEMENT',
            'COLLATERAL', 'PROJECT', 'PROGRAM', 'INVESTMENT', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_treasury_accounts_status_chk CHECK (
        account_status IN (
            'PLANNED', 'PENDING_VERIFICATION', 'ACTIVE', 'RESTRICTED',
            'SUSPENDED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_treasury_accounts_opaque_reference_chk CHECK (
        external_account_reference IS NULL
        OR external_account_reference ~ '^(vault|token|masked|provider):[A-Za-z0-9._:/-]+$'
    ),
    CONSTRAINT capitalization_treasury_accounts_active_evidence_chk CHECK (
        account_status <> 'ACTIVE'
        OR (
            custodian_institution_id IS NOT NULL
            AND external_account_reference IS NOT NULL
            AND reconciliation_source IS NOT NULL
            AND evidence_reference IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.reserve_pools (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reserve_reference text NOT NULL UNIQUE,
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    reserve_type text NOT NULL,
    purpose text NOT NULL CHECK (length(btrim(purpose)) > 0),
    target_amount numeric(38, 12) CHECK (target_amount IS NULL OR target_amount >= 0),
    minimum_amount numeric(38, 12) CHECK (minimum_amount IS NULL OR minimum_amount >= 0),
    reserve_status text NOT NULL DEFAULT 'PLANNED',
    restrictions jsonb NOT NULL DEFAULT '[]'::jsonb,
    governance_reference text,
    evidence_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_reserve_pools_type_chk CHECK (
        reserve_type IN (
            'OPERATING', 'LIQUIDITY', 'STABILIZATION', 'PROJECT',
            'CREDIT_ENHANCEMENT', 'CONTINGENCY', 'STRATEGIC', 'RESTRICTED'
        )
    ),
    CONSTRAINT capitalization_reserve_pools_status_chk CHECK (
        reserve_status IN (
            'PLANNED', 'FUNDING', 'ACTIVE', 'BELOW_MINIMUM',
            'RESTRICTED', 'SUSPENDED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_reserve_pools_threshold_chk CHECK (
        target_amount IS NULL OR minimum_amount IS NULL OR minimum_amount <= target_amount
    ),
    CONSTRAINT capitalization_reserve_pools_active_evidence_chk CHECK (
        reserve_status NOT IN ('ACTIVE', 'BELOW_MINIMUM')
        OR (
            governance_reference IS NOT NULL
            AND evidence_reference IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.treasury_position_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    as_of timestamptz NOT NULL,
    book_balance numeric(38, 12) NOT NULL,
    available_balance numeric(38, 12) NOT NULL,
    restricted_balance numeric(38, 12) NOT NULL DEFAULT 0 CHECK (restricted_balance >= 0),
    committed_balance numeric(38, 12) NOT NULL DEFAULT 0 CHECK (committed_balance >= 0),
    encumbered_balance numeric(38, 12) NOT NULL DEFAULT 0 CHECK (encumbered_balance >= 0),
    valuation_asset_code text NOT NULL
        CHECK (valuation_asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    source_authority text NOT NULL CHECK (length(btrim(source_authority)) > 0),
    external_snapshot_reference text,
    evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) > 0),
    reconciliation_status text NOT NULL DEFAULT 'UNRECONCILED',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (treasury_account_id, as_of, source_authority),
    CONSTRAINT capitalization_treasury_positions_reconciliation_chk CHECK (
        reconciliation_status IN (
            'UNRECONCILED', 'MATCHED', 'VARIANCE', 'REVIEW', 'RECONCILED', 'RESTRICTED'
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.liquidity_position_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    corridor_id uuid REFERENCES capitalization.interbank_corridors(id) ON DELETE RESTRICT,
    as_of timestamptz NOT NULL,
    available_liquidity numeric(38, 12) NOT NULL,
    required_minimum numeric(38, 12) NOT NULL DEFAULT 0 CHECK (required_minimum >= 0),
    projected_inflows numeric(38, 12) NOT NULL DEFAULT 0,
    projected_outflows numeric(38, 12) NOT NULL DEFAULT 0,
    stress_adjusted_liquidity numeric(38, 12),
    methodology_reference text NOT NULL CHECK (length(btrim(methodology_reference)) > 0),
    evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (treasury_account_id, corridor_id, as_of)
);

CREATE TABLE IF NOT EXISTS capitalization.collateral_position_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    collateral_reference text NOT NULL,
    asset_type text NOT NULL,
    quantity numeric(38, 12),
    valuation_amount numeric(38, 12) NOT NULL CHECK (valuation_amount >= 0),
    valuation_asset_code text NOT NULL
        CHECK (valuation_asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    haircut_rate numeric(8, 7) CHECK (haircut_rate IS NULL OR (haircut_rate >= 0 AND haircut_rate <= 1)),
    encumbered boolean NOT NULL DEFAULT false,
    as_of timestamptz NOT NULL,
    valuation_method_reference text NOT NULL,
    evidence_reference text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (treasury_account_id, collateral_reference, as_of),
    CONSTRAINT capitalization_collateral_asset_type_chk CHECK (
        asset_type IN (
            'CASH', 'DEPOSIT', 'SECURITY', 'COMMODITY', 'REAL_ASSET',
            'GUARANTEE', 'DIGITAL_ASSET', 'OTHER'
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.fx_position_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_setc_organization_id text,
    treasury_account_id uuid
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    base_asset_code text NOT NULL
        CHECK (base_asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    quote_asset_code text NOT NULL
        CHECK (quote_asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    notional_amount numeric(38, 12) NOT NULL,
    market_value numeric(38, 12),
    exposure_type text NOT NULL,
    as_of timestamptz NOT NULL,
    valuation_method_reference text NOT NULL,
    evidence_reference text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_fx_positions_owner_chk CHECK (
        owner_setc_organization_id IS NULL
        OR owner_setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_fx_positions_pair_chk CHECK (
        base_asset_code <> quote_asset_code
    ),
    CONSTRAINT capitalization_fx_positions_exposure_chk CHECK (
        exposure_type IN ('ASSET', 'LIABILITY', 'HEDGE', 'FORECAST', 'OTHER')
    )
);

CREATE TABLE IF NOT EXISTS capitalization.institution_relationship_history (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    relationship_id uuid NOT NULL
        REFERENCES capitalization.institution_relationships(id) ON DELETE RESTRICT,
    prior_state text,
    new_state text NOT NULL,
    prior_record jsonb NOT NULL,
    new_record jsonb NOT NULL,
    evidence_reference text,
    changed_by_actor text,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS capitalization.network_connectivity_history (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    network_node_id uuid NOT NULL
        REFERENCES capitalization.network_nodes(id) ON DELETE RESTRICT,
    prior_connectivity_status text,
    new_connectivity_status text NOT NULL,
    prior_record jsonb NOT NULL,
    new_record jsonb NOT NULL,
    evidence_reference text,
    changed_by_actor text,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION capitalization.validate_relationship_live_state()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_verification_status text;
BEGIN
    IF NEW.relationship_state = 'LIVE' THEN
        SELECT verification_status
          INTO v_verification_status
          FROM capitalization.financial_institutions
         WHERE id = NEW.institution_id;

        IF v_verification_status IS DISTINCT FROM 'VERIFIED' THEN
            RAISE EXCEPTION 'LIVE relationship requires VERIFIED institution status'
                USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM capitalization.network_nodes n
             WHERE n.institution_id = NEW.institution_id
               AND n.connectivity_status = 'PRODUCTION'
               AND n.environment = 'PRODUCTION'
               AND n.node_status = 'ACTIVE'
               AND n.evidence_reference IS NOT NULL
               AND n.last_verified_at IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'LIVE relationship requires at least one verified PRODUCTION network node'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_institution_verification_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD.verification_status = 'VERIFIED'
       AND NEW.verification_status <> 'VERIFIED'
       AND EXISTS (
            SELECT 1
              FROM capitalization.institution_relationships r
             WHERE r.institution_id = NEW.id
               AND r.relationship_state = 'LIVE'
       ) THEN
        RAISE EXCEPTION 'demote LIVE relationship before removing VERIFIED institution status'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_network_node_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF NEW.connectivity_status = 'PRODUCTION' THEN
        IF NEW.environment <> 'PRODUCTION'
           OR NEW.node_status <> 'ACTIVE'
           OR NEW.endpoint_reference IS NULL
           OR NEW.evidence_reference IS NULL
           OR NEW.last_verified_at IS NULL THEN
            RAISE EXCEPTION 'PRODUCTION connectivity requires production environment, active status, endpoint, evidence, and verification timestamp'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.connectivity_status = 'PRODUCTION'
       AND NEW.connectivity_status <> 'PRODUCTION'
       AND EXISTS (
            SELECT 1
              FROM capitalization.institution_relationships r
             WHERE r.institution_id = NEW.institution_id
               AND r.relationship_state = 'LIVE'
       ) THEN
        RAISE EXCEPTION 'demote LIVE relationship before removing PRODUCTION connectivity'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.capture_relationship_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD IS DISTINCT FROM NEW THEN
        INSERT INTO capitalization.institution_relationship_history (
            relationship_id,
            prior_state,
            new_state,
            prior_record,
            new_record,
            evidence_reference,
            changed_by_actor
        ) VALUES (
            NEW.id,
            OLD.relationship_state,
            NEW.relationship_state,
            to_jsonb(OLD),
            to_jsonb(NEW),
            NEW.evidence_reference,
            NEW.asserted_by_actor
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.capture_connectivity_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD IS DISTINCT FROM NEW THEN
        INSERT INTO capitalization.network_connectivity_history (
            network_node_id,
            prior_connectivity_status,
            new_connectivity_status,
            prior_record,
            new_record,
            evidence_reference
        ) VALUES (
            NEW.id,
            OLD.connectivity_status,
            NEW.connectivity_status,
            to_jsonb(OLD),
            to_jsonb(NEW),
            NEW.evidence_reference
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE INDEX IF NOT EXISTS capitalization_institutions_setc_idx
    ON capitalization.financial_institutions (setc_organization_id);
CREATE INDEX IF NOT EXISTS capitalization_institutions_wim_idx
    ON capitalization.financial_institutions (wim_organization_id);
CREATE INDEX IF NOT EXISTS capitalization_institutions_status_idx
    ON capitalization.financial_institutions (verification_status, operating_status);
CREATE INDEX IF NOT EXISTS capitalization_relationships_state_idx
    ON capitalization.institution_relationships (relationship_state, last_verified_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_network_nodes_institution_idx
    ON capitalization.network_nodes (institution_id, connectivity_status);
CREATE INDEX IF NOT EXISTS capitalization_external_ids_institution_idx
    ON capitalization.institution_external_identifiers (institution_id, identifier_type);
CREATE INDEX IF NOT EXISTS capitalization_endpoints_node_idx
    ON capitalization.integration_endpoints (node_id, environment, connectivity_status);
CREATE INDEX IF NOT EXISTS capitalization_corridors_status_idx
    ON capitalization.interbank_corridors (corridor_status, asset_code);
CREATE INDEX IF NOT EXISTS capitalization_corridor_participants_institution_idx
    ON capitalization.corridor_participants (institution_id, participation_status);
CREATE INDEX IF NOT EXISTS capitalization_treasury_accounts_owner_idx
    ON capitalization.treasury_accounts (owner_setc_organization_id, account_status);
CREATE INDEX IF NOT EXISTS capitalization_treasury_positions_account_time_idx
    ON capitalization.treasury_position_snapshots (treasury_account_id, as_of DESC);
CREATE INDEX IF NOT EXISTS capitalization_liquidity_positions_account_time_idx
    ON capitalization.liquidity_position_snapshots (treasury_account_id, as_of DESC);
CREATE INDEX IF NOT EXISTS capitalization_collateral_positions_account_time_idx
    ON capitalization.collateral_position_snapshots (treasury_account_id, as_of DESC);
CREATE INDEX IF NOT EXISTS capitalization_fx_positions_time_idx
    ON capitalization.fx_position_snapshots (as_of DESC, base_asset_code, quote_asset_code);

DROP TRIGGER IF EXISTS capitalization_financial_institutions_updated_at
    ON capitalization.financial_institutions;
CREATE TRIGGER capitalization_financial_institutions_updated_at
BEFORE UPDATE ON capitalization.financial_institutions
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_institution_relationships_updated_at
    ON capitalization.institution_relationships;
CREATE TRIGGER capitalization_institution_relationships_updated_at
BEFORE UPDATE ON capitalization.institution_relationships
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_network_nodes_updated_at
    ON capitalization.network_nodes;
CREATE TRIGGER capitalization_network_nodes_updated_at
BEFORE UPDATE ON capitalization.network_nodes
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_external_ids_updated_at
    ON capitalization.institution_external_identifiers;
CREATE TRIGGER capitalization_external_ids_updated_at
BEFORE UPDATE ON capitalization.institution_external_identifiers
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_integration_endpoints_updated_at
    ON capitalization.integration_endpoints;
CREATE TRIGGER capitalization_integration_endpoints_updated_at
BEFORE UPDATE ON capitalization.integration_endpoints
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_interbank_corridors_updated_at
    ON capitalization.interbank_corridors;
CREATE TRIGGER capitalization_interbank_corridors_updated_at
BEFORE UPDATE ON capitalization.interbank_corridors
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_corridor_participants_updated_at
    ON capitalization.corridor_participants;
CREATE TRIGGER capitalization_corridor_participants_updated_at
BEFORE UPDATE ON capitalization.corridor_participants
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_treasury_accounts_updated_at
    ON capitalization.treasury_accounts;
CREATE TRIGGER capitalization_treasury_accounts_updated_at
BEFORE UPDATE ON capitalization.treasury_accounts
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_reserve_pools_updated_at
    ON capitalization.reserve_pools;
CREATE TRIGGER capitalization_reserve_pools_updated_at
BEFORE UPDATE ON capitalization.reserve_pools
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_relationship_live_validation
    ON capitalization.institution_relationships;
CREATE TRIGGER capitalization_relationship_live_validation
BEFORE INSERT OR UPDATE ON capitalization.institution_relationships
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_relationship_live_state();

DROP TRIGGER IF EXISTS capitalization_institution_verification_validation
    ON capitalization.financial_institutions;
CREATE TRIGGER capitalization_institution_verification_validation
BEFORE UPDATE ON capitalization.financial_institutions
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_institution_verification_change();

DROP TRIGGER IF EXISTS capitalization_network_node_validation
    ON capitalization.network_nodes;
CREATE TRIGGER capitalization_network_node_validation
BEFORE INSERT OR UPDATE ON capitalization.network_nodes
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_network_node_change();

DROP TRIGGER IF EXISTS capitalization_relationship_history_capture
    ON capitalization.institution_relationships;
CREATE TRIGGER capitalization_relationship_history_capture
AFTER UPDATE ON capitalization.institution_relationships
FOR EACH ROW EXECUTE FUNCTION capitalization.capture_relationship_history();

DROP TRIGGER IF EXISTS capitalization_connectivity_history_capture
    ON capitalization.network_nodes;
CREATE TRIGGER capitalization_connectivity_history_capture
AFTER UPDATE ON capitalization.network_nodes
FOR EACH ROW EXECUTE FUNCTION capitalization.capture_connectivity_history();

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'financial_institutions',
        'institution_relationships',
        'network_nodes',
        'institution_external_identifiers',
        'integration_endpoints',
        'interbank_corridors',
        'corridor_participants',
        'treasury_accounts',
        'reserve_pools'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON capitalization.%I',
            'capitalization_' || table_name || '_no_delete',
            table_name
        );
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE DELETE ON capitalization.%I FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_delete()',
            'capitalization_' || table_name || '_no_delete',
            table_name
        );
    END LOOP;
END;
$$;

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'treasury_position_snapshots',
        'liquidity_position_snapshots',
        'collateral_position_snapshots',
        'fx_position_snapshots',
        'institution_relationship_history',
        'network_connectivity_history'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON capitalization.%I',
            'capitalization_' || table_name || '_append_only',
            table_name
        );
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE UPDATE OR DELETE ON capitalization.%I FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation()',
            'capitalization_' || table_name || '_append_only',
            table_name
        );
    END LOOP;
END;
$$;

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'financial_institutions',
        'institution_relationships',
        'network_nodes',
        'institution_external_identifiers',
        'integration_endpoints',
        'interbank_corridors',
        'corridor_participants',
        'treasury_accounts',
        'reserve_pools',
        'treasury_position_snapshots',
        'liquidity_position_snapshots',
        'collateral_position_snapshots',
        'fx_position_snapshots',
        'institution_relationship_history',
        'network_connectivity_history'
    ]
    LOOP
        EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY', table_name);
    END LOOP;
END;
$$;

REVOKE ALL ON ALL TABLES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA capitalization TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA capitalization TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization TO service_role;

COMMENT ON TABLE capitalization.financial_institutions IS
'Internal institutional projection. A row does not prove participation, contract, integration, regulatory status, custody, or settlement authority.';
COMMENT ON TABLE capitalization.institution_relationships IS
'Current SourceEnergy relationship lifecycle. TARGET and IDENTIFIED states are registry classifications, not partnership claims.';
COMMENT ON TABLE capitalization.network_nodes IS
'SourceEnergy internal network-node metadata. Dominion Cube and Relay Code are internal identifiers unless independently adopted by an external institution.';
COMMENT ON TABLE capitalization.treasury_accounts IS
'Internal account registry using opaque or masked external references only. Raw account numbers and credentials are prohibited.';
COMMENT ON TABLE capitalization.treasury_position_snapshots IS
'Append-only position observations from an identified source authority. A snapshot is not a bank statement unless the source evidence proves it.';

COMMIT;
