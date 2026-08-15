-- SETC-120 governance, audit, and institutional-control persistence.

CREATE TABLE IF NOT EXISTS setc_governance_authorities (
    authority_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    authority_type TEXT NOT NULL,
    scope TEXT NOT NULL,
    policy_reference TEXT NOT NULL,
    effective_from TIMESTAMPTZ,
    effective_to TIMESTAMPTZ,
    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from)
);

CREATE TABLE IF NOT EXISTS setc_governed_decisions (
    decision_id TEXT PRIMARY KEY,
    subject_reference TEXT NOT NULL,
    decision_type TEXT NOT NULL,
    requested_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    authority_id TEXT NOT NULL REFERENCES setc_governance_authorities(authority_id),
    state TEXT NOT NULL DEFAULT 'PROPOSED',
    evidence_references JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS setc_approval_records (
    approval_id TEXT PRIMARY KEY,
    decision_id TEXT NOT NULL REFERENCES setc_governed_decisions(decision_id),
    approver_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    requested_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    approved BOOLEAN NOT NULL,
    authority_id TEXT NOT NULL REFERENCES setc_governance_authorities(authority_id),
    evidence_reference TEXT NOT NULL,
    decided_at TIMESTAMPTZ,
    CHECK (approver_organization_id <> requested_by_organization_id)
);

CREATE TABLE IF NOT EXISTS setc_policy_versions (
    policy_id TEXT PRIMARY KEY,
    policy_reference TEXT NOT NULL,
    version TEXT NOT NULL,
    issuing_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    effective_at TIMESTAMPTZ NOT NULL,
    supersedes_policy_id TEXT REFERENCES setc_policy_versions(policy_id),
    UNIQUE (policy_reference, version)
);

CREATE TABLE IF NOT EXISTS setc_audit_events (
    audit_event_id TEXT PRIMARY KEY,
    actor_reference TEXT NOT NULL,
    action TEXT NOT NULL,
    subject_reference TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_governance_exceptions (
    exception_id TEXT PRIMARY KEY,
    subject_reference TEXT NOT NULL,
    policy_reference TEXT NOT NULL,
    rationale TEXT NOT NULL,
    approved_by_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    evidence_reference TEXT NOT NULL,
    expires_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS setc_control_findings (
    finding_id TEXT PRIMARY KEY,
    subject_reference TEXT NOT NULL,
    control_reference TEXT NOT NULL,
    finding TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'OPEN',
    evidence_reference TEXT
);

CREATE TABLE IF NOT EXISTS setc_control_remediations (
    remediation_id TEXT PRIMARY KEY,
    finding_id TEXT NOT NULL REFERENCES setc_control_findings(finding_id),
    action TEXT NOT NULL,
    owner_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    evidence_reference TEXT
);

-- Audit and approval rows are historical evidence. Consumers must append status-changing
-- events rather than reinterpret prior approvals as current authority.
