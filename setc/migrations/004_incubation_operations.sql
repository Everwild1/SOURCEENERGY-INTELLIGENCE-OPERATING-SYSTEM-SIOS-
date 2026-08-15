-- SETC-112 incubation operations.

CREATE TABLE IF NOT EXISTS setc_incubation_applications (
    application_id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    applicant_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'APPLICATION',
    submitted_at TIMESTAMPTZ,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_incubation_participations (
    participation_id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES setc_programs(program_id),
    participant_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    cohort_id TEXT REFERENCES setc_cohorts(cohort_id),
    state TEXT NOT NULL DEFAULT 'ADMITTED',
    admitted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    research_reference TEXT,
    ip_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (completed_at IS NULL OR admitted_at IS NULL OR completed_at >= admitted_at)
);

CREATE TABLE IF NOT EXISTS setc_incubation_mentor_assignments (
    assignment_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_incubation_participations(participation_id),
    mentor_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    scope TEXT NOT NULL,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_incubation_resource_access (
    access_grant_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_incubation_participations(participation_id),
    resource_type TEXT NOT NULL,
    granted_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE IF NOT EXISTS setc_incubation_milestones (
    milestone_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_incubation_participations(participation_id),
    name TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'PLANNED',
    evidence_reference TEXT,
    unresolved_risk TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_incubation_handoffs (
    handoff_id TEXT PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_incubation_participations(participation_id),
    handoff_type TEXT NOT NULL,
    target_organization_id TEXT REFERENCES setc_organizations(oid),
    evidence_reference TEXT,
    unresolved_risk TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_incubation_state_history (
    history_id BIGSERIAL PRIMARY KEY,
    participation_id TEXT NOT NULL REFERENCES setc_incubation_participations(participation_id),
    prior_state TEXT,
    new_state TEXT NOT NULL,
    changed_by TEXT,
    reason TEXT,
    evidence_reference TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_setc_incubation_program_state
    ON setc_incubation_participations(program_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_incubation_participant
    ON setc_incubation_participations(participant_organization_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_incubation_milestones_participation
    ON setc_incubation_milestones(participation_id, state);
