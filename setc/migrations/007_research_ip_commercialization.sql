-- SETC-115 research/IP commercialization bridge.

CREATE TABLE IF NOT EXISTS setc_research_assets (
    research_reference TEXT PRIMARY KEY,
    source_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_invention_disclosures (
    disclosure_id TEXT PRIMARY KEY,
    research_reference TEXT NOT NULL REFERENCES setc_research_assets(research_reference),
    disclosing_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    title TEXT NOT NULL,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_ip_assets (
    ip_reference TEXT PRIMARY KEY,
    right_type TEXT NOT NULL,
    claimed_owner_organization_id TEXT REFERENCES setc_organizations(oid),
    evidence_reference TEXT,
    CHECK (right_type IN ('PATENT','COPYRIGHT','TRADE_SECRET','KNOW_HOW','DATA_RIGHT','OTHER'))
);

CREATE TABLE IF NOT EXISTS setc_technology_transfer_authorities (
    authority_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    scope TEXT NOT NULL,
    evidence_reference TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS setc_rights_instruments (
    instrument_id TEXT PRIMARY KEY,
    ip_reference TEXT NOT NULL REFERENCES setc_ip_assets(ip_reference),
    instrument_type TEXT NOT NULL,
    grantor_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    grantee_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    authority_id TEXT NOT NULL REFERENCES setc_technology_transfer_authorities(authority_id),
    evidence_reference TEXT NOT NULL,
    CHECK (grantor_organization_id <> grantee_organization_id),
    CHECK (instrument_type IN ('ASSIGNMENT','LICENSE','OPTION','EVALUATION_RIGHT'))
);

CREATE TABLE IF NOT EXISTS setc_commercialization_opportunities (
    opportunity_id TEXT PRIMARY KEY,
    research_reference TEXT NOT NULL REFERENCES setc_research_assets(research_reference),
    managing_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'DISCLOSED',
    venture_id TEXT REFERENCES setc_venture_origins(venture_id),
    ip_reference TEXT REFERENCES setc_ip_assets(ip_reference),
    CHECK (state IN ('DISCLOSED','UNDER_REVIEW','PROOF_OF_CONCEPT','MARKET_VALIDATION','LICENSING','SPINOUT_PREPARATION','COMMERCIALIZED','SUSPENDED','CLOSED'))
);

-- Provenance and commercialization links do not transfer title. A transfer must be
-- represented by an explicit ASSIGNMENT rights instrument tied to an authority record.
