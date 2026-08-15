-- SETC-117 institutional relationship graph.

CREATE TABLE IF NOT EXISTS setc_organization_relationships (
    relationship_id TEXT PRIMARY KEY,
    source_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    target_organization_id TEXT NOT NULL REFERENCES setc_organizations(oid),
    relationship_type TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'ASSERTED',
    effective_from TIMESTAMPTZ,
    effective_to TIMESTAMPTZ,
    evidence_reference TEXT,
    asserted_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (source_organization_id <> target_organization_id),
    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CHECK (relationship_type IN (
        'OPERATES','OWNS','CONTROLS','MANAGES','FUNDS','GRANTS_TO','INVESTS_IN','LENDS_TO',
        'GUARANTEES','SPONSORS','PARTNERS_WITH','AFFILIATED_WITH','MEMBER_OF','VERIFIED_BY',
        'ACCREDITED_BY','RESEARCHES_WITH','LICENSES_FROM','LICENSES_TO','COMMERCIALIZES',
        'INCUBATES','ACCELERATES','MENTORS','SUPPORTS','CONTRACTS_WITH','PROCURES_FROM',
        'SUPPLIES_TO','REFERS_TO','PARTICIPATES_IN','GOVERNED_BY'
    )),
    CHECK (state IN (
        'PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED',
        'DISPUTED','EXPIRED','TERMINATED','REVOKED','ARCHIVED'
    ))
);

CREATE INDEX IF NOT EXISTS idx_setc_org_rel_source
    ON setc_organization_relationships(source_organization_id, relationship_type, state);
CREATE INDEX IF NOT EXISTS idx_setc_org_rel_target
    ON setc_organization_relationships(target_organization_id, relationship_type, state);
CREATE INDEX IF NOT EXISTS idx_setc_org_rel_effective
    ON setc_organization_relationships(effective_from, effective_to);

-- Material history is recorded separately so relationship state is never silently erased.
CREATE TABLE IF NOT EXISTS setc_organization_relationship_history (
    history_id BIGSERIAL PRIMARY KEY,
    relationship_id TEXT NOT NULL REFERENCES setc_organization_relationships(relationship_id),
    prior_state TEXT,
    new_state TEXT NOT NULL,
    changed_by TEXT,
    reason TEXT,
    evidence_reference TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_setc_org_rel_history_relationship
    ON setc_organization_relationship_history(relationship_id, changed_at);
