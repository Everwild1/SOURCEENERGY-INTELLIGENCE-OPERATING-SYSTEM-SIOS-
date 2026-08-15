-- SETC-113 acceleration operations.

CREATE TABLE IF NOT EXISTS setc_acceleration_participations (
    participation_id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    participant_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    cohort_id TEXT REFERENCES setc_cohorts(cohort_id),
    state TEXT NOT NULL,
    admitted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (completed_at IS NULL OR admitted_at IS NULL OR completed_at >= admitted_at)
);

CREATE TABLE IF NOT EXISTS setc_acceleration_traction_evidence (
    evidence_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_acceleration_participations(participation_id),
    evidence_type TEXT NOT NULL CHECK (length(trim(evidence_type)) > 0),
    quality TEXT NOT NULL DEFAULT 'SELF_REPORTED' CHECK (quality IN ('SELF_REPORTED','INTERNALLY_REVIEWED','VERIFIED','EXTERNALLY_ATTESTED')),
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_acceleration_partner_engagements (
    engagement_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_acceleration_participations(participation_id),
    partner_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    scope TEXT NOT NULL CHECK (length(trim(scope)) > 0),
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_acceleration_preparations (
    preparation_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_acceleration_participations(participation_id),
    preparation_type TEXT NOT NULL CHECK (preparation_type IN ('INVESTOR','PROCUREMENT')),
    state TEXT NOT NULL CHECK (state IN ('NOT_STARTED','IN_PROGRESS','COMPLETED','BLOCKED')),
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_capital_readiness_referrals (
    referral_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_acceleration_participations(participation_id),
    target_organization_id TEXT REFERENCES setc_organizations(oid),
    evidence_reference TEXT,
    unresolved_risk TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Referrals intentionally contain no certification or readiness-score columns.
-- SETC-116 remains the independent authority for capital-readiness classification.
