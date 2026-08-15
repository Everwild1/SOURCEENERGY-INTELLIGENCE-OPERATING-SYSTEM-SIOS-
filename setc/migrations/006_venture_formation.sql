-- SETC-114 venture formation and entrepreneurship-center persistence.

CREATE TABLE IF NOT EXISTS setc_venture_origins (
    venture_id TEXT PRIMARY KEY,
    origin_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    origin_program_id TEXT REFERENCES setc_programs(program_id),
    research_reference TEXT,
    ip_reference TEXT,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_founder_relationships (
    relationship_id TEXT PRIMARY KEY,
    venture_id TEXT NOT NULL REFERENCES setc_venture_origins(venture_id),
    person_reference TEXT NOT NULL,
    role TEXT NOT NULL,
    authority TEXT NOT NULL DEFAULT 'NONE',
    effective_from TIMESTAMPTZ,
    effective_to TIMESTAMPTZ,
    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CHECK (role IN ('FOUNDER','CO_FOUNDER','FOUNDING_EXECUTIVE','ADVISOR')),
    CHECK (authority IN ('NONE','REPRESENTATIVE','SIGNATORY','GOVERNANCE'))
);

CREATE TABLE IF NOT EXISTS setc_legal_entity_formations (
    formation_id TEXT PRIMARY KEY,
    venture_id TEXT NOT NULL REFERENCES setc_venture_origins(venture_id),
    legal_entity_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    jurisdiction TEXT NOT NULL,
    registration_reference TEXT,
    formed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_venture_studio_relationships (
    relationship_id TEXT PRIMARY KEY,
    venture_id TEXT NOT NULL REFERENCES setc_venture_origins(venture_id),
    studio_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    scope TEXT NOT NULL,
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_enterprise_activations (
    activation_id TEXT PRIMARY KEY,
    venture_id TEXT NOT NULL REFERENCES setc_venture_origins(venture_id),
    enterprise_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'ENTERPRISE_ACTIVATION',
    activated_at TIMESTAMPTZ,
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_venture_sponsors (
    relationship_id TEXT PRIMARY KEY,
    venture_id TEXT NOT NULL REFERENCES setc_venture_origins(venture_id),
    sponsor_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    sponsorship_type TEXT NOT NULL,
    evidence_reference TEXT
);

-- Research and IP references above are provenance links only. This schema intentionally
-- creates no ownership-transfer column, assignment flag, or implicit title mutation.
