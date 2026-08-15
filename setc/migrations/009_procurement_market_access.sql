-- Procurement and market-access persistence.

CREATE TABLE IF NOT EXISTS setc_procurement_readiness_profiles (
    profile_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'NOT_ASSESSED',
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb,
    capital_readiness_certification_id TEXT REFERENCES setc_readiness_certifications(certification_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_procurement_opportunities (
    opportunity_id TEXT PRIMARY KEY,
    buyer_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    title TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'DRAFT',
    opens_at TIMESTAMPTZ,
    closes_at TIMESTAMPTZ,
    eligibility_requirements JSONB NOT NULL DEFAULT '[]'::jsonb,
    CHECK (closes_at IS NULL OR opens_at IS NULL OR closes_at > opens_at)
);

CREATE TABLE IF NOT EXISTS setc_supplier_qualifications (
    qualification_id TEXT PRIMARY KEY,
    opportunity_id TEXT NOT NULL REFERENCES setc_procurement_opportunities(opportunity_id),
    supplier_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    qualified BOOLEAN NOT NULL,
    evidence_reference TEXT NOT NULL,
    reviewed_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    CHECK (supplier_organization_id <> reviewed_by_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_procurement_bids (
    bid_id TEXT PRIMARY KEY,
    opportunity_id TEXT NOT NULL REFERENCES setc_procurement_opportunities(opportunity_id),
    supplier_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'DRAFT',
    proposal_reference TEXT,
    compliance_evidence JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS setc_procurement_awards (
    award_id TEXT PRIMARY KEY,
    opportunity_id TEXT NOT NULL REFERENCES setc_procurement_opportunities(opportunity_id),
    bid_id TEXT NOT NULL REFERENCES setc_procurement_bids(bid_id),
    buyer_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    supplier_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    evidence_reference TEXT NOT NULL,
    awarded_at TIMESTAMPTZ NOT NULL,
    CHECK (buyer_organization_id <> supplier_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_market_access_referrals (
    referral_id TEXT PRIMARY KEY,
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    referring_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    target_market TEXT NOT NULL,
    evidence_reference TEXT,
    CHECK (subject_organization_id <> referring_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_contract_performance_records (
    performance_id TEXT PRIMARY KEY,
    award_id TEXT NOT NULL REFERENCES setc_procurement_awards(award_id),
    metric TEXT NOT NULL,
    value TEXT NOT NULL,
    evidence_reference TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- A capital-readiness certification is evidence only. It does not set procurement
-- readiness, qualify a supplier, award a contract, or guarantee market access.
