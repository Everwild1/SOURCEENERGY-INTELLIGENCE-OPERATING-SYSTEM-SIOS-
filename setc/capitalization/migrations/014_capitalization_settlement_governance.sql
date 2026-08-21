-- SourceEnergy Capitalization Block settlement, compliance, approval, audit,
-- reconciliation, and integration controls.
-- Finality belongs to the authoritative external fiat rail, Source Coin domain,
-- or an independently approved treasury system identified in evidence.

BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.compliance_cases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_reference text NOT NULL UNIQUE,
    subject_type text NOT NULL,
    subject_reference text NOT NULL CHECK (length(btrim(subject_reference)) > 0),
    case_type text NOT NULL,
    case_status text NOT NULL DEFAULT 'OPEN',
    decision text,
    reviewer_reference text,
    evidence_reference text,
    opened_at timestamptz NOT NULL DEFAULT now(),
    decided_at timestamptz,
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_compliance_cases_subject_chk CHECK (
        subject_type IN (
            'CAPITAL_SOURCE', 'COMMITMENT', 'ALLOCATION', 'INSTITUTION',
            'CORRIDOR', 'TREASURY_ACCOUNT', 'SETTLEMENT', 'DEPLOYMENT', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_compliance_cases_type_chk CHECK (
        case_type IN (
            'KYC', 'KYB', 'AML', 'SANCTIONS', 'COUNTERPARTY', 'CORRIDOR',
            'TRANSACTION_MONITORING', 'EXPORT_CONTROL', 'SOURCE_OF_FUNDS',
            'LEGAL_REGULATORY', 'PRIVACY', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_compliance_cases_status_chk CHECK (
        case_status IN (
            'OPEN', 'IN_REVIEW', 'CLEARED', 'NOT_REQUIRED', 'RESTRICTED',
            'DENIED', 'CLOSED'
        )
    ),
    CONSTRAINT capitalization_compliance_cases_decision_chk CHECK (
        decision IS NULL OR decision IN ('ALLOW', 'RESTRICT', 'DENY', 'NOT_APPLICABLE')
    ),
    CONSTRAINT capitalization_compliance_cases_decision_evidence_chk CHECK (
        case_status NOT IN ('CLEARED', 'NOT_REQUIRED', 'RESTRICTED', 'DENIED', 'CLOSED')
        OR (
            decision IS NOT NULL
            AND reviewer_reference IS NOT NULL
            AND evidence_reference IS NOT NULL
            AND decided_at IS NOT NULL
        )
    ),
    CONSTRAINT capitalization_compliance_cases_closed_chk CHECK (
        case_status <> 'CLOSED' OR closed_at IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS capitalization.compliance_checks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compliance_case_id uuid NOT NULL
        REFERENCES capitalization.compliance_cases(id) ON DELETE RESTRICT,
    check_reference text NOT NULL UNIQUE,
    check_type text NOT NULL,
    result text NOT NULL,
    provider_reference text,
    evidence_reference text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    performed_by_actor text,
    performed_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_compliance_checks_type_chk CHECK (
        check_type IN (
            'IDENTITY', 'BENEFICIAL_OWNERSHIP', 'SANCTIONS', 'PEP', 'ADVERSE_MEDIA',
            'SOURCE_OF_FUNDS', 'COUNTERPARTY', 'CORRIDOR', 'DOCUMENTATION',
            'TRANSACTION_MONITORING', 'EXPORT_CONTROL', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_compliance_checks_result_chk CHECK (
        result IN ('PENDING', 'PASS', 'FAIL', 'REVIEW', 'RESTRICTED', 'NOT_APPLICABLE')
    ),
    CONSTRAINT capitalization_compliance_checks_evidence_chk CHECK (
        result = 'PENDING'
        OR (evidence_reference IS NOT NULL AND length(btrim(evidence_reference)) > 0)
    )
);

CREATE TABLE IF NOT EXISTS capitalization.approval_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_reference text NOT NULL UNIQUE,
    target_type text NOT NULL,
    target_reference text NOT NULL CHECK (length(btrim(target_reference)) > 0),
    action_type text NOT NULL,
    requested_by_actor text NOT NULL CHECK (length(btrim(requested_by_actor)) > 0),
    required_approvals integer NOT NULL DEFAULT 1 CHECK (required_approvals > 0),
    request_status text NOT NULL DEFAULT 'PENDING',
    policy_reference text NOT NULL CHECK (length(btrim(policy_reference)) > 0),
    evidence_reference text,
    requested_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_approval_requests_target_chk CHECK (
        target_type IN (
            'COMMITMENT', 'FACILITY', 'ALLOCATION', 'DEPLOYMENT',
            'TREASURY_ACTION', 'RELATIONSHIP', 'CORRIDOR', 'SETTLEMENT',
            'RELEASE_GATE', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_approval_requests_status_chk CHECK (
        request_status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED')
    ),
    CONSTRAINT capitalization_approval_requests_dates_chk CHECK (
        expires_at IS NULL OR expires_at > requested_at
    ),
    CONSTRAINT capitalization_approval_requests_decided_chk CHECK (
        request_status = 'PENDING' OR decided_at IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS capitalization.approval_actions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL
        REFERENCES capitalization.approval_requests(id) ON DELETE RESTRICT,
    actioned_by_actor text NOT NULL CHECK (length(btrim(actioned_by_actor)) > 0),
    decision text NOT NULL,
    rationale text,
    evidence_reference text,
    actioned_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (approval_request_id, actioned_by_actor),
    CONSTRAINT capitalization_approval_actions_decision_chk CHECK (
        decision IN ('APPROVE', 'REJECT', 'ABSTAIN')
    ),
    CONSTRAINT capitalization_approval_actions_evidence_chk CHECK (
        decision = 'ABSTAIN'
        OR (
            rationale IS NOT NULL
            AND length(btrim(rationale)) > 0
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_instructions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instruction_reference text NOT NULL UNIQUE,
    commitment_id uuid REFERENCES capitalization.capital_commitments(id) ON DELETE RESTRICT,
    allocation_id uuid REFERENCES capitalization.capital_allocations(id) ON DELETE RESTRICT,
    deployment_id uuid REFERENCES capitalization.capital_deployments(id) ON DELETE RESTRICT,
    wim_transaction_id uuid,
    approval_request_id uuid
        REFERENCES capitalization.approval_requests(id) ON DELETE RESTRICT,
    compliance_case_id uuid
        REFERENCES capitalization.compliance_cases(id) ON DELETE RESTRICT,
    corridor_id uuid
        REFERENCES capitalization.interbank_corridors(id) ON DELETE RESTRICT,
    origin_treasury_account_id uuid
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    destination_treasury_account_id uuid
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    rail_type text NOT NULL,
    environment text NOT NULL DEFAULT 'SANDBOX',
    amount numeric(38, 12) NOT NULL CHECK (amount > 0),
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    idempotency_key text NOT NULL UNIQUE,
    correlation_id text NOT NULL CHECK (length(btrim(correlation_id)) > 0),
    causation_id text,
    settlement_status text NOT NULL DEFAULT 'DRAFT',
    external_provider_reference text,
    source_coin_request_reference text,
    finality_authority text,
    authoritative_confirmation_reference text,
    requested_execution_at timestamptz,
    submitted_at timestamptz,
    accepted_at timestamptz,
    settled_at timestamptz,
    expires_at timestamptz,
    failure_code text,
    failure_detail text,
    authority_boundary text NOT NULL DEFAULT 'orchestration_only_finality_external',
    evidence_reference text,
    created_by_actor text NOT NULL CHECK (length(btrim(created_by_actor)) > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_settlements_rail_chk CHECK (
        rail_type IN ('FIAT_EXTERNAL', 'SOURCE_COIN', 'INTERNAL_BOOK_TRANSFER')
    ),
    CONSTRAINT capitalization_settlements_environment_chk CHECK (
        environment IN ('SANDBOX', 'TEST', 'CERTIFICATION', 'PRODUCTION')
    ),
    CONSTRAINT capitalization_settlements_status_chk CHECK (
        settlement_status IN (
            'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'SUBMITTED', 'ACCEPTED',
            'SETTLED', 'FAILED', 'CANCELLED', 'REVERSED', 'RESTRICTED', 'EXPIRED'
        )
    ),
    CONSTRAINT capitalization_settlements_accounts_chk CHECK (
        origin_treasury_account_id IS NULL
        OR destination_treasury_account_id IS NULL
        OR origin_treasury_account_id <> destination_treasury_account_id
    ),
    CONSTRAINT capitalization_settlements_expiry_chk CHECK (
        expires_at IS NULL OR expires_at > created_at
    ),
    CONSTRAINT capitalization_settlements_source_coin_chk CHECK (
        rail_type <> 'SOURCE_COIN'
        OR settlement_status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'RESTRICTED', 'CANCELLED', 'EXPIRED')
        OR source_coin_request_reference IS NOT NULL
    ),
    CONSTRAINT capitalization_settlements_fiat_provider_chk CHECK (
        rail_type <> 'FIAT_EXTERNAL'
        OR settlement_status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'RESTRICTED', 'CANCELLED', 'EXPIRED')
        OR external_provider_reference IS NOT NULL
    ),
    CONSTRAINT capitalization_settlements_finality_chk CHECK (
        settlement_status <> 'SETTLED'
        OR (
            finality_authority IS NOT NULL
            AND length(btrim(finality_authority)) > 0
            AND authoritative_confirmation_reference IS NOT NULL
            AND length(btrim(authoritative_confirmation_reference)) > 0
            AND settled_at IS NOT NULL
            AND evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
        )
    ),
    CONSTRAINT capitalization_settlements_source_coin_finality_chk CHECK (
        rail_type <> 'SOURCE_COIN'
        OR settlement_status <> 'SETTLED'
        OR finality_authority = 'SOURCE_COIN_DOMAIN'
    ),
    CONSTRAINT capitalization_settlements_no_self_finality_chk CHECK (
        settlement_status <> 'SETTLED'
        OR finality_authority <> 'CAPITALIZATION_BLOCK'
    )
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_confirmations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_instruction_id uuid NOT NULL
        REFERENCES capitalization.settlement_instructions(id) ON DELETE RESTRICT,
    confirmation_reference text NOT NULL UNIQUE,
    finality_authority text NOT NULL CHECK (length(btrim(finality_authority)) > 0),
    confirmation_status text NOT NULL,
    confirmed_amount numeric(38, 12) CHECK (confirmed_amount IS NULL OR confirmed_amount > 0),
    confirmed_asset_code text
        CHECK (confirmed_asset_code IS NULL OR confirmed_asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    provider_event_reference text,
    payload_hash text,
    evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) > 0),
    confirmed_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_settlement_confirmations_status_chk CHECK (
        confirmation_status IN ('ACCEPTED', 'SETTLED', 'FAILED', 'REVERSED', 'REJECTED')
    ),
    CONSTRAINT capitalization_settlement_confirmations_authority_chk CHECK (
        finality_authority <> 'CAPITALIZATION_BLOCK'
    )
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_status_history (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    settlement_instruction_id uuid NOT NULL
        REFERENCES capitalization.settlement_instructions(id) ON DELETE RESTRICT,
    prior_status text,
    new_status text NOT NULL,
    prior_record jsonb NOT NULL,
    new_record jsonb NOT NULL,
    evidence_reference text,
    actor_reference text,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_corrections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_instruction_id uuid NOT NULL
        REFERENCES capitalization.settlement_instructions(id) ON DELETE RESTRICT,
    correction_reference text NOT NULL UNIQUE,
    correction_type text NOT NULL,
    prior_state jsonb NOT NULL,
    corrected_state jsonb NOT NULL,
    reason text NOT NULL CHECK (length(btrim(reason)) > 0),
    evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) > 0),
    authorized_by_actor text NOT NULL CHECK (length(btrim(authorized_by_actor)) > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_settlement_corrections_type_chk CHECK (
        correction_type IN (
            'METADATA', 'REFERENCE', 'AMOUNT', 'STATUS_COMPENSATION',
            'REVERSAL_REFERENCE', 'RECONCILIATION', 'OTHER'
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.reconciliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_reference text NOT NULL UNIQUE,
    settlement_instruction_id uuid NOT NULL
        REFERENCES capitalization.settlement_instructions(id) ON DELETE RESTRICT,
    confirmation_id uuid
        REFERENCES capitalization.settlement_confirmations(id) ON DELETE RESTRICT,
    reconciliation_status text NOT NULL DEFAULT 'PENDING',
    instructed_amount numeric(38, 12) NOT NULL,
    confirmed_amount numeric(38, 12),
    variance_amount numeric(38, 12),
    asset_code text NOT NULL CHECK (asset_code ~ '^[A-Z0-9][A-Z0-9._-]{1,11}$'),
    source_authority text NOT NULL CHECK (length(btrim(source_authority)) > 0),
    performed_by_actor text,
    evidence_reference text,
    reconciled_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_reconciliations_status_chk CHECK (
        reconciliation_status IN (
            'PENDING', 'MATCHED', 'VARIANCE', 'REVIEW', 'RECONCILED', 'FAILED', 'RESTRICTED'
        )
    ),
    CONSTRAINT capitalization_reconciliations_reconciled_chk CHECK (
        reconciliation_status <> 'RECONCILED'
        OR (
            confirmation_id IS NOT NULL
            AND performed_by_actor IS NOT NULL
            AND evidence_reference IS NOT NULL
            AND reconciled_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.risk_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_reference text NOT NULL UNIQUE,
    subject_type text NOT NULL,
    subject_reference text NOT NULL,
    risk_type text NOT NULL,
    severity text NOT NULL,
    risk_status text NOT NULL DEFAULT 'OPEN',
    description text NOT NULL,
    owner_actor text,
    treatment_reference text,
    evidence_reference text,
    opened_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_risk_events_subject_chk CHECK (
        subject_type IN (
            'INSTITUTION', 'CORRIDOR', 'TREASURY_ACCOUNT', 'COMMITMENT',
            'ALLOCATION', 'SETTLEMENT', 'DEPLOYMENT', 'SYSTEM', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_risk_events_type_chk CHECK (
        risk_type IN (
            'CREDIT', 'LIQUIDITY', 'MARKET', 'FX', 'OPERATIONAL', 'CYBER',
            'COMPLIANCE', 'LEGAL', 'COUNTERPARTY', 'CONCENTRATION',
            'REPUTATIONAL', 'DATA_QUALITY', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_risk_events_severity_chk CHECK (
        severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
    ),
    CONSTRAINT capitalization_risk_events_status_chk CHECK (
        risk_status IN (
            'OPEN', 'ASSESSING', 'TREATING', 'ACCEPTED', 'MITIGATED',
            'CLOSED', 'ESCALATED'
        )
    ),
    CONSTRAINT capitalization_risk_events_closed_chk CHECK (
        risk_status <> 'CLOSED' OR closed_at IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS capitalization.audit_events (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    event_reference text NOT NULL UNIQUE,
    event_type text NOT NULL CHECK (length(btrim(event_type)) > 0),
    subject_type text NOT NULL CHECK (length(btrim(subject_type)) > 0),
    subject_reference text NOT NULL CHECK (length(btrim(subject_reference)) > 0),
    actor_reference text,
    correlation_id text,
    causation_id text,
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    evidence_reference text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS capitalization.outbox_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id text NOT NULL UNIQUE,
    aggregate_type text NOT NULL,
    aggregate_reference text NOT NULL,
    event_type text NOT NULL,
    contract_name text NOT NULL,
    contract_version text NOT NULL DEFAULT '1.0',
    correlation_id text NOT NULL,
    causation_id text,
    destination text NOT NULL,
    payload jsonb NOT NULL,
    delivery_status text NOT NULL DEFAULT 'PENDING',
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    next_attempt_at timestamptz,
    published_at timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_outbox_status_chk CHECK (
        delivery_status IN ('PENDING', 'PROCESSING', 'PUBLISHED', 'FAILED', 'DEAD_LETTER')
    ),
    CONSTRAINT capitalization_outbox_destination_chk CHECK (
        destination IN ('SETC', 'WIM', 'SOURCE_COIN', 'FIAT_ADAPTER', 'AUDIT', 'OTHER')
    )
);

CREATE TABLE IF NOT EXISTS capitalization.inbox_receipts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_name text NOT NULL,
    event_id text NOT NULL,
    contract_name text NOT NULL,
    contract_version text NOT NULL,
    producer text NOT NULL,
    correlation_id text NOT NULL,
    causation_id text,
    payload_hash text NOT NULL,
    processing_status text NOT NULL DEFAULT 'RECEIVED',
    result_reference text,
    error_code text,
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (consumer_name, event_id),
    CONSTRAINT capitalization_inbox_status_chk CHECK (
        processing_status IN ('RECEIVED', 'PROCESSED', 'REJECTED', 'FAILED', 'DUPLICATE')
    )
);

CREATE TABLE IF NOT EXISTS capitalization.release_gate_history (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    gate_code text NOT NULL REFERENCES capitalization.release_gates(gate_code) ON DELETE RESTRICT,
    prior_enabled boolean NOT NULL,
    new_enabled boolean NOT NULL,
    prior_record jsonb NOT NULL,
    new_record jsonb NOT NULL,
    authorization_reference text NOT NULL,
    evidence_reference text NOT NULL,
    authorized_by_actor text NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION capitalization.settlement_transition_allowed(
    p_prior text,
    p_new text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
    SELECT CASE p_prior
        WHEN 'DRAFT' THEN p_new IN ('DRAFT', 'PENDING_APPROVAL', 'CANCELLED')
        WHEN 'PENDING_APPROVAL' THEN p_new IN ('PENDING_APPROVAL', 'APPROVED', 'RESTRICTED', 'CANCELLED')
        WHEN 'APPROVED' THEN p_new IN ('APPROVED', 'SUBMITTED', 'RESTRICTED', 'CANCELLED', 'EXPIRED')
        WHEN 'SUBMITTED' THEN p_new IN ('SUBMITTED', 'ACCEPTED', 'FAILED', 'CANCELLED', 'RESTRICTED')
        WHEN 'ACCEPTED' THEN p_new IN ('ACCEPTED', 'SETTLED', 'FAILED', 'REVERSED', 'RESTRICTED')
        WHEN 'SETTLED' THEN p_new IN ('SETTLED', 'REVERSED')
        WHEN 'RESTRICTED' THEN p_new IN ('RESTRICTED', 'PENDING_APPROVAL', 'APPROVED', 'CANCELLED')
        WHEN 'FAILED' THEN p_new = 'FAILED'
        WHEN 'CANCELLED' THEN p_new = 'CANCELLED'
        WHEN 'REVERSED' THEN p_new = 'REVERSED'
        WHEN 'EXPIRED' THEN p_new = 'EXPIRED'
        ELSE false
    END;
$$;

CREATE OR REPLACE FUNCTION capitalization.release_gate_enabled(p_gate_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, capitalization
AS $$
    SELECT COALESCE((
        SELECT enabled
          FROM capitalization.release_gates
         WHERE gate_code = p_gate_code
    ), false);
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_approval_action()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_requester text;
    v_request_status text;
BEGIN
    SELECT requested_by_actor, request_status
      INTO v_requester, v_request_status
      FROM capitalization.approval_requests
     WHERE id = NEW.approval_request_id;

    IF v_requester IS NULL THEN
        RAISE EXCEPTION 'approval request does not exist'
            USING ERRCODE = '23503';
    END IF;

    IF v_request_status <> 'PENDING' THEN
        RAISE EXCEPTION 'approval actions are allowed only while request is PENDING'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.decision IN ('APPROVE', 'REJECT')
       AND NEW.actioned_by_actor = v_requester THEN
        RAISE EXCEPTION 'requester cannot approve or reject their own request'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_approval_request_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_approvals integer;
    v_rejections integer;
BEGIN
    IF NEW.request_status = 'APPROVED' AND OLD.request_status <> 'APPROVED' THEN
        SELECT
            count(*) FILTER (WHERE decision = 'APPROVE'),
            count(*) FILTER (WHERE decision = 'REJECT')
          INTO v_approvals, v_rejections
          FROM capitalization.approval_actions
         WHERE approval_request_id = NEW.id;

        IF v_approvals < NEW.required_approvals OR v_rejections > 0 THEN
            RAISE EXCEPTION 'APPROVED request requires the configured approvals and no rejection'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.request_status = 'REJECTED' AND OLD.request_status <> 'REJECTED' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM capitalization.approval_actions
             WHERE approval_request_id = NEW.id
               AND decision = 'REJECT'
        ) THEN
            RAISE EXCEPTION 'REJECTED request requires a recorded rejection action'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_settlement_instruction()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_approval_status text;
    v_compliance_status text;
BEGIN
    IF TG_OP = 'UPDATE'
       AND NOT capitalization.settlement_transition_allowed(
            OLD.settlement_status,
            NEW.settlement_status
       ) THEN
        RAISE EXCEPTION 'invalid settlement transition: % -> %',
            OLD.settlement_status, NEW.settlement_status
            USING ERRCODE = '23514';
    END IF;

    IF NEW.settlement_status IN ('PENDING_APPROVAL', 'APPROVED', 'SUBMITTED', 'ACCEPTED', 'SETTLED')
       AND NEW.approval_request_id IS NULL THEN
        RAISE EXCEPTION '% settlement requires an approval request', NEW.settlement_status
            USING ERRCODE = '23514';
    END IF;

    IF NEW.settlement_status IN ('APPROVED', 'SUBMITTED', 'ACCEPTED', 'SETTLED') THEN
        SELECT request_status
          INTO v_approval_status
          FROM capitalization.approval_requests
         WHERE id = NEW.approval_request_id;

        IF v_approval_status IS DISTINCT FROM 'APPROVED' THEN
            RAISE EXCEPTION '% settlement requires an APPROVED approval request', NEW.settlement_status
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.settlement_status IN ('SUBMITTED', 'ACCEPTED', 'SETTLED') THEN
        IF NEW.compliance_case_id IS NULL THEN
            RAISE EXCEPTION '% settlement requires a compliance case', NEW.settlement_status
                USING ERRCODE = '23514';
        END IF;

        SELECT case_status
          INTO v_compliance_status
          FROM capitalization.compliance_cases
         WHERE id = NEW.compliance_case_id;

        IF v_compliance_status NOT IN ('CLEARED', 'NOT_REQUIRED') THEN
            RAISE EXCEPTION '% settlement requires CLEARED or NOT_REQUIRED compliance disposition', NEW.settlement_status
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.environment = 'PRODUCTION'
       AND NEW.settlement_status IN ('SUBMITTED', 'ACCEPTED', 'SETTLED')
       AND NOT capitalization.release_gate_enabled('PRODUCTION_SETTLEMENT') THEN
        RAISE EXCEPTION 'production settlement gate is disabled'
            USING ERRCODE = '42501';
    END IF;

    IF NEW.settlement_status = 'SUBMITTED' AND NEW.submitted_at IS NULL THEN
        NEW.submitted_at := now();
    END IF;

    IF NEW.settlement_status = 'ACCEPTED' AND NEW.accepted_at IS NULL THEN
        NEW.accepted_at := now();
    END IF;

    IF NEW.settlement_status = 'SETTLED' THEN
        IF NEW.finality_authority IS NULL
           OR NEW.authoritative_confirmation_reference IS NULL
           OR NEW.settled_at IS NULL
           OR NEW.evidence_reference IS NULL THEN
            RAISE EXCEPTION 'SETTLED requires independent finality authority, confirmation, timestamp, and evidence'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.finality_authority = 'CAPITALIZATION_BLOCK' THEN
            RAISE EXCEPTION 'Capitalization Block cannot self-confer settlement finality'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.rail_type = 'SOURCE_COIN'
           AND NEW.finality_authority <> 'SOURCE_COIN_DOMAIN' THEN
            RAISE EXCEPTION 'Source Coin finality belongs to SOURCE_COIN_DOMAIN'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.capture_settlement_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD IS DISTINCT FROM NEW THEN
        INSERT INTO capitalization.settlement_status_history (
            settlement_instruction_id,
            prior_status,
            new_status,
            prior_record,
            new_record,
            evidence_reference,
            actor_reference
        ) VALUES (
            NEW.id,
            OLD.settlement_status,
            NEW.settlement_status,
            to_jsonb(OLD),
            to_jsonb(NEW),
            NEW.evidence_reference,
            NEW.created_by_actor
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.capture_release_gate_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD.enabled IS DISTINCT FROM NEW.enabled THEN
        INSERT INTO capitalization.release_gate_history (
            gate_code,
            prior_enabled,
            new_enabled,
            prior_record,
            new_record,
            authorization_reference,
            evidence_reference,
            authorized_by_actor
        ) VALUES (
            NEW.gate_code,
            OLD.enabled,
            NEW.enabled,
            to_jsonb(OLD),
            to_jsonb(NEW),
            NEW.authorization_reference,
            NEW.evidence_reference,
            NEW.authorized_by_actor
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.authorize_release_gate(
    p_gate_code text,
    p_enabled boolean,
    p_authorization_reference text,
    p_evidence_reference text,
    p_authorized_by_actor text,
    p_rationale text
)
RETURNS capitalization.release_gates
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_result capitalization.release_gates;
BEGIN
    IF p_gate_code NOT IN ('PRODUCTION_SETTLEMENT', 'PUBLIC_LIVE_NETWORK_CLAIMS') THEN
        RAISE EXCEPTION 'unsupported release gate: %', p_gate_code
            USING ERRCODE = '22023';
    END IF;

    IF length(btrim(p_authorization_reference)) = 0
       OR length(btrim(p_evidence_reference)) = 0
       OR length(btrim(p_authorized_by_actor)) = 0
       OR length(btrim(p_rationale)) = 0 THEN
        RAISE EXCEPTION 'release-gate change requires authorization, evidence, actor, and rationale'
            USING ERRCODE = '22023';
    END IF;

    UPDATE capitalization.release_gates
       SET enabled = p_enabled,
           authorization_reference = btrim(p_authorization_reference),
           evidence_reference = btrim(p_evidence_reference),
           authorized_by_actor = btrim(p_authorized_by_actor),
           authorized_at = now(),
           rationale = btrim(p_rationale),
           version = version + 1
     WHERE gate_code = p_gate_code
     RETURNING * INTO v_result;

    IF v_result.gate_code IS NULL THEN
        RAISE EXCEPTION 'release gate not found: %', p_gate_code
            USING ERRCODE = 'P0002';
    END IF;

    RETURN v_result;
END;
$$;

CREATE INDEX IF NOT EXISTS capitalization_compliance_cases_subject_idx
    ON capitalization.compliance_cases (subject_type, subject_reference, case_status);
CREATE INDEX IF NOT EXISTS capitalization_compliance_checks_case_idx
    ON capitalization.compliance_checks (compliance_case_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_approval_requests_target_idx
    ON capitalization.approval_requests (target_type, target_reference, request_status);
CREATE INDEX IF NOT EXISTS capitalization_approval_actions_request_idx
    ON capitalization.approval_actions (approval_request_id, decision);
CREATE INDEX IF NOT EXISTS capitalization_settlements_status_idx
    ON capitalization.settlement_instructions (environment, settlement_status, created_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_settlements_wim_idx
    ON capitalization.settlement_instructions (wim_transaction_id)
    WHERE wim_transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS capitalization_settlements_ecid_idx
    ON capitalization.settlement_instructions (commitment_id, allocation_id, deployment_id);
CREATE INDEX IF NOT EXISTS capitalization_settlement_history_instruction_idx
    ON capitalization.settlement_status_history (settlement_instruction_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_reconciliations_instruction_idx
    ON capitalization.reconciliations (settlement_instruction_id, reconciliation_status);
CREATE INDEX IF NOT EXISTS capitalization_risk_events_subject_idx
    ON capitalization.risk_events (subject_type, subject_reference, risk_status, severity);
CREATE INDEX IF NOT EXISTS capitalization_audit_events_subject_idx
    ON capitalization.audit_events (subject_type, subject_reference, occurred_at DESC);
CREATE INDEX IF NOT EXISTS capitalization_audit_events_correlation_idx
    ON capitalization.audit_events (correlation_id)
    WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS capitalization_outbox_delivery_idx
    ON capitalization.outbox_events (delivery_status, next_attempt_at, created_at);
CREATE INDEX IF NOT EXISTS capitalization_inbox_consumer_status_idx
    ON capitalization.inbox_receipts (consumer_name, processing_status, received_at DESC);

DROP TRIGGER IF EXISTS capitalization_compliance_cases_updated_at
    ON capitalization.compliance_cases;
CREATE TRIGGER capitalization_compliance_cases_updated_at
BEFORE UPDATE ON capitalization.compliance_cases
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_approval_requests_updated_at
    ON capitalization.approval_requests;
CREATE TRIGGER capitalization_approval_requests_updated_at
BEFORE UPDATE ON capitalization.approval_requests
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_settlement_instructions_updated_at
    ON capitalization.settlement_instructions;
CREATE TRIGGER capitalization_settlement_instructions_updated_at
BEFORE UPDATE ON capitalization.settlement_instructions
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_reconciliations_updated_at
    ON capitalization.reconciliations;
CREATE TRIGGER capitalization_reconciliations_updated_at
BEFORE UPDATE ON capitalization.reconciliations
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_risk_events_updated_at
    ON capitalization.risk_events;
CREATE TRIGGER capitalization_risk_events_updated_at
BEFORE UPDATE ON capitalization.risk_events
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_outbox_events_updated_at
    ON capitalization.outbox_events;
CREATE TRIGGER capitalization_outbox_events_updated_at
BEFORE UPDATE ON capitalization.outbox_events
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_approval_action_validation
    ON capitalization.approval_actions;
CREATE TRIGGER capitalization_approval_action_validation
BEFORE INSERT ON capitalization.approval_actions
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_approval_action();

DROP TRIGGER IF EXISTS capitalization_approval_request_status_validation
    ON capitalization.approval_requests;
CREATE TRIGGER capitalization_approval_request_status_validation
BEFORE UPDATE ON capitalization.approval_requests
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_approval_request_status();

DROP TRIGGER IF EXISTS capitalization_settlement_instruction_validation
    ON capitalization.settlement_instructions;
CREATE TRIGGER capitalization_settlement_instruction_validation
BEFORE INSERT OR UPDATE ON capitalization.settlement_instructions
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_settlement_instruction();

DROP TRIGGER IF EXISTS capitalization_settlement_history_capture
    ON capitalization.settlement_instructions;
CREATE TRIGGER capitalization_settlement_history_capture
AFTER UPDATE ON capitalization.settlement_instructions
FOR EACH ROW EXECUTE FUNCTION capitalization.capture_settlement_history();

DROP TRIGGER IF EXISTS capitalization_release_gate_history_capture
    ON capitalization.release_gates;
CREATE TRIGGER capitalization_release_gate_history_capture
AFTER UPDATE ON capitalization.release_gates
FOR EACH ROW EXECUTE FUNCTION capitalization.capture_release_gate_history();

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'compliance_cases',
        'approval_requests',
        'settlement_instructions',
        'reconciliations',
        'risk_events',
        'outbox_events'
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
        'compliance_checks',
        'approval_actions',
        'settlement_confirmations',
        'settlement_status_history',
        'settlement_corrections',
        'audit_events',
        'inbox_receipts',
        'release_gate_history'
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
        'compliance_cases',
        'compliance_checks',
        'approval_requests',
        'approval_actions',
        'settlement_instructions',
        'settlement_confirmations',
        'settlement_status_history',
        'settlement_corrections',
        'reconciliations',
        'risk_events',
        'audit_events',
        'outbox_events',
        'inbox_receipts',
        'release_gate_history'
    ]
    LOOP
        EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY', table_name);
    END LOOP;
END;
$$;

REVOKE UPDATE ON capitalization.release_gates FROM service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA capitalization TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA capitalization TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA capitalization TO service_role;
REVOKE UPDATE ON capitalization.release_gates FROM service_role;
GRANT EXECUTE ON FUNCTION capitalization.authorize_release_gate(
    text, boolean, text, text, text, text
) TO service_role;

COMMENT ON TABLE capitalization.settlement_instructions IS
'Orchestration instructions only. SETTLED requires confirmation from an external finality authority; Capitalization Block cannot self-confer finality.';
COMMENT ON TABLE capitalization.approval_actions IS
'Append-only separation-of-duties evidence. Requesters may not approve or reject their own material actions.';
COMMENT ON TABLE capitalization.inbox_receipts IS
'Replay-protection receipts for cross-context events. Unique consumer/event identity prevents duplicate processing records.';
COMMENT ON FUNCTION capitalization.authorize_release_gate(
    text, boolean, text, text, text, text
) IS
'Only governed server-side release-gate changes. Every enable or disable action requires authorization, evidence, accountable actor, and rationale.';

COMMIT;
