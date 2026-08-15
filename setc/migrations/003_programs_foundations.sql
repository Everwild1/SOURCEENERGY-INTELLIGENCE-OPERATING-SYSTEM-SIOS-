-- SETC-111/112/113 program substrate and foundation philanthropic capital.

CREATE TABLE IF NOT EXISTS setc_programs (
    program_id TEXT PRIMARY KEY,
    operating_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    program_type TEXT NOT NULL CHECK (program_type IN ('INCUBATION','ACCELERATION','ENTREPRENEURSHIP','RESEARCH','FELLOWSHIP','GRANT','PILOT','CAPACITY_BUILDING')),
    state TEXT NOT NULL DEFAULT 'DRAFT' CHECK (state IN ('DRAFT','ACTIVE','SUSPENDED','COMPLETED','CANCELLED')),
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_program_sponsors (
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    sponsor_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    PRIMARY KEY (program_id, sponsor_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_cohorts (
    cohort_id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    state TEXT NOT NULL DEFAULT 'PLANNED' CHECK (state IN ('PLANNED','ENROLLING','ACTIVE','COMPLETED','CANCELLED')),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE IF NOT EXISTS setc_program_participations (
    participation_id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    cohort_id TEXT REFERENCES setc_cohorts(cohort_id),
    participant_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'APPLIED' CHECK (state IN ('NOMINATED','APPLIED','ADMITTED','ACTIVE','COMPLETED','WITHDRAWN','REMOVED')),
    admitted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    evidence_reference TEXT,
    CHECK (completed_at IS NULL OR admitted_at IS NULL OR completed_at >= admitted_at)
);

CREATE TABLE IF NOT EXISTS setc_foundation_profiles (
    foundation_organization_id TEXT PRIMARY KEY REFERENCES setc_organizations(oid),
    mission TEXT NOT NULL CHECK (length(trim(mission)) > 0),
    thematic_priorities JSONB NOT NULL DEFAULT '[]'::jsonb,
    geographic_mandates JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_funding_instruments (
    instrument_id TEXT PRIMARY KEY,
    foundation_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    instrument_type TEXT NOT NULL CHECK (instrument_type IN ('GRANT','CHALLENGE_GRANT','MATCHING_GRANT','RECOVERABLE_GRANT','PROGRAM_RELATED_INVESTMENT','MISSION_RELATED_INVESTMENT','GUARANTEE','FIRST_LOSS_CAPITAL','TECHNICAL_ASSISTANCE','RESEARCH_FUNDING','COMMERCIALIZATION_SUPPORT')),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    currency CHAR(3),
    maximum_amount NUMERIC(20,2) CHECK (maximum_amount IS NULL OR maximum_amount > 0),
    restrictions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_grant_awards (
    award_id TEXT PRIMARY KEY,
    foundation_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    recipient_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    instrument_id TEXT NOT NULL REFERENCES setc_funding_instruments(instrument_id),
    program_id TEXT REFERENCES setc_programs(program_id),
    amount NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL,
    state TEXT NOT NULL DEFAULT 'DRAFT' CHECK (state IN ('DRAFT','RECOMMENDED','APPROVED','COMMITTED','PARTIALLY_DISBURSED','DISBURSED','SUSPENDED','RECOVERED','CLOSED','CANCELLED')),
    research_reference TEXT,
    venture_reference TEXT,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (foundation_organization_id <> recipient_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_grant_milestones (
    milestone_id TEXT PRIMARY KEY,
    award_id TEXT NOT NULL REFERENCES setc_grant_awards(award_id),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    state TEXT NOT NULL DEFAULT 'PLANNED' CHECK (state IN ('PLANNED','SUBMITTED','ACCEPTED','REJECTED','WAIVED')),
    due_date DATE,
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_impact_reports (
    report_id TEXT PRIMARY KEY,
    award_id TEXT NOT NULL REFERENCES setc_grant_awards(award_id),
    metric_name TEXT NOT NULL CHECK (length(trim(metric_name)) > 0),
    metric_value NUMERIC NOT NULL,
    unit TEXT NOT NULL CHECK (length(trim(unit)) > 0),
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_setc_program_operator ON setc_programs(operating_organization_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_program_participant ON setc_program_participations(participant_organization_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_award_foundation ON setc_grant_awards(foundation_organization_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_award_recipient ON setc_grant_awards(recipient_organization_id, state);
