-- SETC-117 / SETC-119 canonical Organizations foundation.
-- PostgreSQL migration; deliberately independent from the existing ssr subsystem.

CREATE TABLE IF NOT EXISTS setc_organizations (
    oid TEXT PRIMARY KEY CHECK (oid ~ '^SETC-OID-[0-9a-f]{32}$'),
    legal_name TEXT NOT NULL CHECK (length(btrim(legal_name)) > 0),
    normalized_name TEXT NOT NULL,
    organization_type TEXT NOT NULL,
    verification_state TEXT NOT NULL DEFAULT 'UNVERIFIED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived_at TIMESTAMPTZ,
    CONSTRAINT setc_organizations_verification_state_chk CHECK (
        verification_state IN (
            'UNVERIFIED','PENDING_VERIFICATION','VERIFIED','ENHANCED_VERIFICATION',
            'ACCREDITED','SUSPENDED','REVOKED','ARCHIVED'
        )
    )
);

CREATE INDEX IF NOT EXISTS setc_organizations_normalized_name_idx
    ON setc_organizations (normalized_name);

CREATE TABLE IF NOT EXISTS setc_organization_aliases (
    organization_oid TEXT NOT NULL REFERENCES setc_organizations(oid) ON DELETE CASCADE,
    alias TEXT NOT NULL CHECK (length(btrim(alias)) > 0),
    normalized_alias TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_oid, normalized_alias)
);

CREATE INDEX IF NOT EXISTS setc_organization_alias_lookup_idx
    ON setc_organization_aliases (normalized_alias);

CREATE TABLE IF NOT EXISTS setc_organization_capabilities (
    organization_oid TEXT NOT NULL REFERENCES setc_organizations(oid) ON DELETE CASCADE,
    capability TEXT NOT NULL,
    asserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_oid, capability)
);

CREATE TABLE IF NOT EXISTS setc_organization_external_ids (
    organization_oid TEXT NOT NULL REFERENCES setc_organizations(oid) ON DELETE CASCADE,
    namespace TEXT NOT NULL,
    external_id TEXT NOT NULL,
    source TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (namespace, external_id),
    UNIQUE (organization_oid, namespace, external_id)
);

COMMENT ON TABLE setc_organizations IS
'Canonical SETC institutional identities. Capabilities and relationships extend identity; they do not mint duplicate organizations.';
