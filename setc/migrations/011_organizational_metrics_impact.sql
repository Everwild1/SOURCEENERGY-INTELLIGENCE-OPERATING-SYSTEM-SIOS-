-- Organizational metrics and impact ledger.

CREATE TABLE IF NOT EXISTS setc_metric_definitions (
    metric_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    value_type TEXT NOT NULL,
    unit TEXT NOT NULL,
    description TEXT NOT NULL,
    version TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS setc_measurement_periods (
    period_id TEXT PRIMARY KEY,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    CHECK (ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS setc_metric_observations (
    observation_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    metric_id TEXT NOT NULL REFERENCES setc_metric_definitions(metric_id),
    period_id TEXT NOT NULL REFERENCES setc_measurement_periods(period_id),
    value TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'REPORTED',
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb,
    program_id TEXT REFERENCES setc_programs(program_id),
    venture_id TEXT REFERENCES setc_venture_origins(venture_id),
    observed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS setc_metric_targets (
    target_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    metric_id TEXT NOT NULL REFERENCES setc_metric_definitions(metric_id),
    period_id TEXT NOT NULL REFERENCES setc_measurement_periods(period_id),
    baseline_value NUMERIC,
    target_value NUMERIC,
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_impact_claims (
    claim_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    claim TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ASSERTED',
    metric_observation_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS setc_impact_validations (
    validation_id TEXT PRIMARY KEY,
    claim_id TEXT NOT NULL REFERENCES setc_impact_claims(claim_id),
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    validator_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    validated BOOLEAN NOT NULL,
    evidence_reference TEXT NOT NULL,
    validated_at TIMESTAMPTZ,
    CHECK (subject_organization_id <> validator_organization_id)
);

-- Observations and claims are not certifications, valuations, investment returns,
-- or institutional endorsements. Validation requires explicit independent evidence.
