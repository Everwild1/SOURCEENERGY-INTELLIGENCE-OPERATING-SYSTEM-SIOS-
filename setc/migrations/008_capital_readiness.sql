-- SETC-116 capital readiness assessment and certification persistence.

CREATE TABLE IF NOT EXISTS setc_readiness_frameworks (
    framework_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    pathway TEXT NOT NULL,
    version TEXT NOT NULL,
    UNIQUE (name, pathway, version)
);

CREATE TABLE IF NOT EXISTS setc_readiness_dimensions (
    dimension_id TEXT PRIMARY KEY,
    framework_id TEXT NOT NULL REFERENCES setc_readiness_frameworks(framework_id),
    name TEXT NOT NULL,
    weight NUMERIC NOT NULL CHECK (weight > 0)
);

CREATE TABLE IF NOT EXISTS setc_readiness_assessments (
    assessment_id TEXT PRIMARY KEY,
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    framework_id TEXT NOT NULL REFERENCES setc_readiness_frameworks(framework_id),
    reviewer_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    state TEXT NOT NULL DEFAULT 'REQUESTED',
    requested_at TIMESTAMPTZ,
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (subject_organization_id <> reviewer_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_readiness_findings (
    finding_id TEXT PRIMARY KEY,
    assessment_id TEXT NOT NULL REFERENCES setc_readiness_assessments(assessment_id),
    dimension_id TEXT NOT NULL REFERENCES setc_readiness_dimensions(dimension_id),
    score NUMERIC NOT NULL CHECK (score >= 0 AND score <= 100),
    evidence_reference TEXT NOT NULL,
    deficiency TEXT
);

CREATE TABLE IF NOT EXISTS setc_readiness_remediation (
    remediation_id TEXT PRIMARY KEY,
    assessment_id TEXT NOT NULL REFERENCES setc_readiness_assessments(assessment_id),
    finding_id TEXT NOT NULL REFERENCES setc_readiness_findings(finding_id),
    action TEXT NOT NULL,
    evidence_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_readiness_certifications (
    certification_id TEXT PRIMARY KEY,
    assessment_id TEXT NOT NULL REFERENCES setc_readiness_assessments(assessment_id),
    subject_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    pathway TEXT NOT NULL,
    state TEXT NOT NULL,
    issued_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    conditions JSONB NOT NULL DEFAULT '[]'::jsonb,
    evidence_reference TEXT,
    CHECK (subject_organization_id <> issued_by_organization_id),
    CHECK (expires_at IS NULL OR expires_at > issued_at),
    CHECK (state IN ('ACTIVE','CONDITIONAL','EXPIRED','SUSPENDED','REVOKED'))
);

CREATE TABLE IF NOT EXISTS setc_readiness_certification_history (
    history_id BIGSERIAL PRIMARY KEY,
    certification_id TEXT NOT NULL REFERENCES setc_readiness_certifications(certification_id),
    prior_state TEXT,
    new_state TEXT NOT NULL,
    changed_by TEXT NOT NULL,
    reason TEXT,
    evidence_reference TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_setc_readiness_subject ON setc_readiness_assessments(subject_organization_id, state);
CREATE INDEX IF NOT EXISTS idx_setc_certification_subject ON setc_readiness_certifications(subject_organization_id, pathway, state);
