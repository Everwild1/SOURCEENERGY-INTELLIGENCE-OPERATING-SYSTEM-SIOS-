-- SETC-119 cross-cutting verification, credential, and evidence controls.

CREATE TABLE IF NOT EXISTS setc_evidence_records (
    evidence_id TEXT PRIMARY KEY,
    subject_reference TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    classification TEXT NOT NULL DEFAULT 'INTERNAL',
    collected_at TIMESTAMPTZ,
    hash_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED'))
);

CREATE TABLE IF NOT EXISTS setc_verification_authorities (
    authority_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    scope TEXT NOT NULL,
    evidence_reference TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS setc_verifications (
    verification_id TEXT PRIMARY KEY,
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    verifier_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    authority_id TEXT NOT NULL REFERENCES setc_verification_authorities(authority_id),
    claim_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ASSERTED',
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (subject_organization_id <> verifier_organization_id),
    CHECK (status IN ('ASSERTED','PENDING','VERIFIED','REJECTED','EXPIRED','SUSPENDED','REVOKED')),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from)
);

CREATE TABLE IF NOT EXISTS setc_credentials (
    credential_id TEXT PRIMARY KEY,
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    issuer_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    credential_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    issued_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (subject_organization_id <> issuer_organization_id),
    CHECK (status IN ('ACTIVE','EXPIRED','SUSPENDED','REVOKED')),
    CHECK (expires_at IS NULL OR issued_at IS NULL OR expires_at > issued_at)
);

CREATE TABLE IF NOT EXISTS setc_accreditation_mappings (
    mapping_id TEXT PRIMARY KEY,
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    accrediting_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    credential_id TEXT NOT NULL REFERENCES setc_credentials(credential_id),
    accreditation_reference TEXT NOT NULL,
    CHECK (subject_organization_id <> accrediting_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_verification_history (
    history_id BIGSERIAL PRIMARY KEY,
    verification_id TEXT NOT NULL REFERENCES setc_verifications(verification_id),
    prior_status TEXT,
    new_status TEXT NOT NULL,
    evidence_reference TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
