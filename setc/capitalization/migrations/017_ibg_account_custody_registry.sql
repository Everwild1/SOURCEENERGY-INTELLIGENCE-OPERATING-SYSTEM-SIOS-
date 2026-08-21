-- IBG-02 Account & Custody Registry
-- Extends the existing treasury account model; does not create a second bank-account source of truth.
-- Registry presence never confers banking, custody, payment, settlement, or regulatory authority.

BEGIN;

ALTER TABLE capitalization.treasury_accounts
    ADD COLUMN IF NOT EXISTS jurisdiction_code text,
    ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'UNVERIFIED',
    ADD COLUMN IF NOT EXISTS last_verified_at timestamptz,
    ADD COLUMN IF NOT EXISTS operational_eligibility text NOT NULL DEFAULT 'REFERENCE_ONLY';

ALTER TABLE capitalization.treasury_accounts
    DROP CONSTRAINT IF EXISTS capitalization_treasury_accounts_verification_chk;
ALTER TABLE capitalization.treasury_accounts
    ADD CONSTRAINT capitalization_treasury_accounts_verification_chk CHECK (
        verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'RESTRICTED', 'SUSPENDED')
    );

ALTER TABLE capitalization.treasury_accounts
    DROP CONSTRAINT IF EXISTS capitalization_treasury_accounts_eligibility_chk;
ALTER TABLE capitalization.treasury_accounts
    ADD CONSTRAINT capitalization_treasury_accounts_eligibility_chk CHECK (
        operational_eligibility IN (
            'REFERENCE_ONLY', 'INTERNAL_REVIEW', 'NON_PRODUCTION', 'PRODUCTION_ELIGIBLE'
        )
    );

CREATE TABLE IF NOT EXISTS capitalization.account_ownerships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    owner_setc_organization_id text,
    beneficial_owner_reference text,
    ownership_role text NOT NULL,
    ownership_status text NOT NULL DEFAULT 'CANDIDATE',
    evidence_reference text,
    verified_at timestamptz,
    effective_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_account_ownerships_owner_chk CHECK (
        owner_setc_organization_id IS NULL
        OR owner_setc_organization_id ~ '^SETC-OID-[0-9a-f]{32}$'
    ),
    CONSTRAINT capitalization_account_ownerships_role_chk CHECK (
        ownership_role IN (
            'LEGAL_OWNER', 'BENEFICIAL_OWNER', 'TRUSTEE', 'NOMINEE',
            'FIDUCIARY', 'PROGRAM_OWNER', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_account_ownerships_status_chk CHECK (
        ownership_status IN (
            'CANDIDATE', 'DUE_DILIGENCE', 'VERIFIED', 'ACTIVE',
            'RESTRICTED', 'SUSPENDED', 'TERMINATED'
        )
    ),
    CONSTRAINT capitalization_account_ownerships_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    ),
    CONSTRAINT capitalization_account_ownerships_evidence_chk CHECK (
        ownership_status NOT IN ('VERIFIED', 'ACTIVE')
        OR (
            evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND verified_at IS NOT NULL
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.custody_arrangements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    custody_reference text NOT NULL UNIQUE,
    treasury_account_id uuid
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    custodian_institution_id uuid NOT NULL
        REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
    custody_type text NOT NULL,
    custody_status text NOT NULL DEFAULT 'CANDIDATE',
    agreement_reference text,
    evidence_reference text,
    verified_at timestamptz,
    effective_at timestamptz,
    expires_at timestamptz,
    restrictions jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_custody_type_chk CHECK (
        custody_type IN (
            'DEPOSITORY', 'SECURITIES', 'COLLATERAL', 'ESCROW',
            'SAFEGUARDING', 'DIGITAL_ASSET', 'SUBCUSTODY', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_custody_status_chk CHECK (
        custody_status IN (
            'CANDIDATE', 'DUE_DILIGENCE', 'VERIFIED', 'CONTRACTED', 'ACTIVE',
            'RESTRICTED', 'SUSPENDED', 'TERMINATED'
        )
    ),
    CONSTRAINT capitalization_custody_dates_chk CHECK (
        expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at
    ),
    CONSTRAINT capitalization_custody_evidence_chk CHECK (
        custody_status NOT IN ('VERIFIED', 'CONTRACTED', 'ACTIVE')
        OR (
            evidence_reference IS NOT NULL
            AND length(btrim(evidence_reference)) > 0
            AND verified_at IS NOT NULL
        )
    ),
    CONSTRAINT capitalization_custody_agreement_chk CHECK (
        custody_status NOT IN ('CONTRACTED', 'ACTIVE')
        OR (
            agreement_reference IS NOT NULL
            AND length(btrim(agreement_reference)) > 0
        )
    )
);

CREATE TABLE IF NOT EXISTS capitalization.account_evidence (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    evidence_type text NOT NULL,
    evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) > 0),
    verification_status text NOT NULL DEFAULT 'PENDING',
    verified_by_actor text,
    verified_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_account_evidence_type_chk CHECK (
        evidence_type IN (
            'ACCOUNT_EXISTENCE', 'OWNERSHIP', 'CUSTODY', 'ACCOUNT_AGREEMENT',
            'BANK_CONFIRMATION', 'REGULATORY', 'KYC_KYB', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_account_evidence_status_chk CHECK (
        verification_status IN ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED', 'RESTRICTED')
    ),
    CONSTRAINT capitalization_account_evidence_verified_chk CHECK (
        verification_status <> 'VERIFIED'
        OR (verified_at IS NOT NULL AND verified_by_actor IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS capitalization.account_restrictions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    restriction_type text NOT NULL,
    restriction_status text NOT NULL DEFAULT 'ACTIVE',
    reason text NOT NULL CHECK (length(btrim(reason)) > 0),
    governance_reference text,
    effective_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    lifted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT capitalization_account_restrictions_type_chk CHECK (
        restriction_type IN (
            'NO_PAYMENTS', 'NO_WITHDRAWALS', 'NO_CUSTODY_MOVEMENT', 'COMPLIANCE_HOLD',
            'EVIDENCE_EXPIRED', 'INSTITUTION_RESTRICTED', 'MANUAL_REVIEW', 'OTHER'
        )
    ),
    CONSTRAINT capitalization_account_restrictions_status_chk CHECK (
        restriction_status IN ('ACTIVE', 'LIFTED', 'EXPIRED')
    ),
    CONSTRAINT capitalization_account_restrictions_dates_chk CHECK (
        expires_at IS NULL OR expires_at > effective_at
    )
);

CREATE TABLE IF NOT EXISTS capitalization.account_status_history (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    treasury_account_id uuid NOT NULL
        REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
    prior_status text,
    new_status text NOT NULL,
    prior_eligibility text,
    new_eligibility text NOT NULL,
    prior_verification_status text,
    new_verification_status text NOT NULL,
    prior_record jsonb NOT NULL,
    new_record jsonb NOT NULL,
    evidence_reference text,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION capitalization.validate_treasury_account_ibg_state()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_institution_verification text;
    v_institution_operating text;
BEGIN
    IF NEW.account_status = 'ACTIVE'
       OR NEW.operational_eligibility = 'PRODUCTION_ELIGIBLE' THEN
        IF NEW.custodian_institution_id IS NULL THEN
            RAISE EXCEPTION 'active or production-eligible account requires custodian institution'
                USING ERRCODE = '23514';
        END IF;

        SELECT verification_status, operating_status
          INTO v_institution_verification, v_institution_operating
          FROM capitalization.financial_institutions
         WHERE id = NEW.custodian_institution_id;

        IF v_institution_verification IS DISTINCT FROM 'VERIFIED'
           OR v_institution_operating NOT IN ('APPROVED', 'ACTIVE') THEN
            RAISE EXCEPTION 'account activation requires VERIFIED and approved/active parent institution'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.verification_status <> 'VERIFIED'
           OR NEW.last_verified_at IS NULL
           OR NEW.evidence_reference IS NULL
           OR NEW.external_account_reference IS NULL THEN
            RAISE EXCEPTION 'account activation requires verified account evidence and opaque external reference'
                USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM capitalization.institution_relationships r
             WHERE r.institution_id = NEW.custodian_institution_id
               AND r.relationship_state IN (
                    'CONTRACTED', 'INTEGRATION_PENDING', 'INTEGRATED', 'LIVE'
               )
               AND r.evidence_reference IS NOT NULL
               AND r.agreement_reference IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'account activation requires evidence-backed institutional relationship'
                USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM capitalization.account_restrictions ar
             WHERE ar.treasury_account_id = NEW.id
               AND ar.restriction_status = 'ACTIVE'
               AND (ar.expires_at IS NULL OR ar.expires_at > now())
        ) THEN
            RAISE EXCEPTION 'restricted account cannot be active or production eligible'
                USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM capitalization.account_evidence ae
             WHERE ae.treasury_account_id = NEW.id
               AND ae.evidence_type = 'ACCOUNT_EXISTENCE'
               AND ae.verification_status = 'VERIFIED'
               AND (ae.expires_at IS NULL OR ae.expires_at > now())
        ) THEN
            RAISE EXCEPTION 'account activation requires current verified ACCOUNT_EXISTENCE evidence'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.operational_eligibility = 'PRODUCTION_ELIGIBLE'
       AND NEW.account_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'PRODUCTION_ELIGIBLE requires ACTIVE account status'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.validate_custody_arrangement_state()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
DECLARE
    v_institution_verification text;
    v_institution_operating text;
BEGIN
    IF NEW.custody_status IN ('CONTRACTED', 'ACTIVE') THEN
        SELECT verification_status, operating_status
          INTO v_institution_verification, v_institution_operating
          FROM capitalization.financial_institutions
         WHERE id = NEW.custodian_institution_id;

        IF v_institution_verification IS DISTINCT FROM 'VERIFIED'
           OR v_institution_operating NOT IN ('APPROVED', 'ACTIVE') THEN
            RAISE EXCEPTION 'contracted/active custody requires VERIFIED and approved/active custodian institution'
                USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM capitalization.institution_relationships r
             WHERE r.institution_id = NEW.custodian_institution_id
               AND r.relationship_state IN ('CONTRACTED', 'INTEGRATION_PENDING', 'INTEGRATED', 'LIVE')
               AND r.relationship_purpose IN ('CUSTODY', 'TREASURY', 'INTERBANK_NETWORK')
               AND r.evidence_reference IS NOT NULL
               AND r.agreement_reference IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'contracted/active custody requires evidence-backed custody-capable relationship'
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION capitalization.capture_account_status_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, capitalization
AS $$
BEGIN
    IF OLD.account_status IS DISTINCT FROM NEW.account_status
       OR OLD.operational_eligibility IS DISTINCT FROM NEW.operational_eligibility
       OR OLD.verification_status IS DISTINCT FROM NEW.verification_status THEN
        INSERT INTO capitalization.account_status_history (
            treasury_account_id,
            prior_status,
            new_status,
            prior_eligibility,
            new_eligibility,
            prior_verification_status,
            new_verification_status,
            prior_record,
            new_record,
            evidence_reference
        ) VALUES (
            NEW.id,
            OLD.account_status,
            NEW.account_status,
            OLD.operational_eligibility,
            NEW.operational_eligibility,
            OLD.verification_status,
            NEW.verification_status,
            to_jsonb(OLD),
            to_jsonb(NEW),
            NEW.evidence_reference
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS capitalization_treasury_accounts_ibg_validation
    ON capitalization.treasury_accounts;
CREATE TRIGGER capitalization_treasury_accounts_ibg_validation
BEFORE INSERT OR UPDATE ON capitalization.treasury_accounts
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_treasury_account_ibg_state();

DROP TRIGGER IF EXISTS capitalization_custody_arrangements_ibg_validation
    ON capitalization.custody_arrangements;
CREATE TRIGGER capitalization_custody_arrangements_ibg_validation
BEFORE INSERT OR UPDATE ON capitalization.custody_arrangements
FOR EACH ROW EXECUTE FUNCTION capitalization.validate_custody_arrangement_state();

DROP TRIGGER IF EXISTS capitalization_account_status_history_capture
    ON capitalization.treasury_accounts;
CREATE TRIGGER capitalization_account_status_history_capture
AFTER UPDATE ON capitalization.treasury_accounts
FOR EACH ROW EXECUTE FUNCTION capitalization.capture_account_status_history();

DROP TRIGGER IF EXISTS capitalization_account_ownerships_updated_at
    ON capitalization.account_ownerships;
CREATE TRIGGER capitalization_account_ownerships_updated_at
BEFORE UPDATE ON capitalization.account_ownerships
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DROP TRIGGER IF EXISTS capitalization_custody_arrangements_updated_at
    ON capitalization.custody_arrangements;
CREATE TRIGGER capitalization_custody_arrangements_updated_at
BEFORE UPDATE ON capitalization.custody_arrangements
FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'account_ownerships',
        'custody_arrangements',
        'account_evidence',
        'account_restrictions',
        'account_status_history'
    ]
    LOOP
        EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY', table_name);
    END LOOP;
END;
$$;

DROP TRIGGER IF EXISTS capitalization_account_status_history_append_only
    ON capitalization.account_status_history;
CREATE TRIGGER capitalization_account_status_history_append_only
BEFORE UPDATE OR DELETE ON capitalization.account_status_history
FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

REVOKE ALL ON capitalization.account_ownerships FROM PUBLIC, anon, authenticated;
REVOKE ALL ON capitalization.custody_arrangements FROM PUBLIC, anon, authenticated;
REVOKE ALL ON capitalization.account_evidence FROM PUBLIC, anon, authenticated;
REVOKE ALL ON capitalization.account_restrictions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON capitalization.account_status_history FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.account_ownerships TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.custody_arrangements TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.account_evidence TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.account_restrictions TO service_role;
GRANT SELECT, INSERT ON capitalization.account_status_history TO service_role;

CREATE OR REPLACE VIEW capitalization_api.account_registry AS
SELECT
    ta.account_reference,
    ta.owner_setc_organization_id,
    fi.institution_reference AS custodian_institution_reference,
    fi.display_name AS custodian_display_name,
    ta.account_type,
    ta.asset_code,
    ta.jurisdiction_code,
    CASE
        WHEN ta.external_account_reference IS NULL THEN NULL
        WHEN ta.external_account_reference LIKE 'masked:%' THEN ta.external_account_reference
        ELSE 'tokenized:withheld'
    END AS masked_external_account_reference,
    ta.account_status,
    ta.verification_status,
    ta.operational_eligibility,
    ta.last_verified_at,
    (ta.operational_eligibility = 'PRODUCTION_ELIGIBLE') AS production_eligible,
    CASE
        WHEN ta.operational_eligibility = 'PRODUCTION_ELIGIBLE'
            THEN 'Evidence-gated internal eligibility; no settlement finality or payment authority implied.'
        ELSE 'Reference-only or non-production account registry metadata.'
    END AS disclosure
FROM capitalization.treasury_accounts ta
LEFT JOIN capitalization.financial_institutions fi
  ON fi.id = ta.custodian_institution_id;

REVOKE ALL ON capitalization_api.account_registry FROM PUBLIC, anon;
GRANT SELECT ON capitalization_api.account_registry TO authenticated, service_role;

COMMENT ON TABLE capitalization.account_ownerships IS
'IBG-02 ownership/beneficial-interest evidence. Rows do not independently establish legal ownership.';
COMMENT ON TABLE capitalization.custody_arrangements IS
'IBG-02 custody registry. CANDIDATE and DUE_DILIGENCE states do not establish custody authority or a contractual relationship.';
COMMENT ON TABLE capitalization.account_evidence IS
'Controlled evidence references only; raw account documents, credentials, and secrets are prohibited.';
COMMENT ON VIEW capitalization_api.account_registry IS
'Authenticated read-safe account registry projection. Raw account numbers, credentials, balances, and settlement authority are excluded.';

COMMIT;
