-- TST-WP02 / issue #164
-- Identity, role assignment, delegation, and organization-scoped permission contract.
-- Deny-by-default remains in force; this migration creates no client table grants.

CREATE TABLE IF NOT EXISTS tst.participants (
  participant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
  auth_user_id uuid NOT NULL UNIQUE,
  display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','REVOKED','ARCHIVED')),
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE INDEX IF NOT EXISTS tst_participants_entity_status_idx
  ON tst.participants(stewardship_entity_id, status);
CREATE INDEX IF NOT EXISTS tst_participants_org_status_idx
  ON tst.participants(organization_oid, status);

CREATE TABLE IF NOT EXISTS tst.role_assignments (
  role_assignment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
  role_code text NOT NULL REFERENCES tst.roles(role_code) ON DELETE RESTRICT,
  authority_limit numeric(20,2) CHECK (authority_limit IS NULL OR authority_limit >= 0),
  currency char(3) CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to timestamptz,
  approval_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE INDEX IF NOT EXISTS tst_role_assignments_participant_idx
  ON tst.role_assignments(participant_id, status, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS tst_role_assignments_scope_idx
  ON tst.role_assignments(stewardship_entity_id, organization_oid, role_code, status);
CREATE UNIQUE INDEX IF NOT EXISTS tst_role_assignments_active_unique
  ON tst.role_assignments(participant_id, stewardship_entity_id, organization_oid, role_code)
  WHERE status = 'ACTIVE' AND effective_to IS NULL;

CREATE TABLE IF NOT EXISTS tst.authority_delegations (
  delegation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delegator_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  delegate_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
  permission_code text NOT NULL REFERENCES tst.permissions(permission_code) ON DELETE RESTRICT,
  authority_limit numeric(20,2) CHECK (authority_limit IS NULL OR authority_limit >= 0),
  currency char(3) CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
  purpose text NOT NULL CHECK (length(btrim(purpose)) > 0),
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','EXPIRED','REVOKED','REJECTED')),
  effective_from timestamptz NOT NULL,
  effective_to timestamptz NOT NULL,
  approval_reference text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (delegator_participant_id <> delegate_participant_id),
  CHECK (effective_to > effective_from)
);
CREATE INDEX IF NOT EXISTS tst_authority_delegations_delegate_idx
  ON tst.authority_delegations(delegate_participant_id, status, effective_from, effective_to);

INSERT INTO tst.role_permissions(role_code,permission_code) VALUES
('TST_TRUSTEE','TST_READ_ASSIGNED'),
('TST_TRUSTEE','TST_APPROVE_FIDUCIARY'),
('TST_PROGRAM_OFFICER','TST_READ_ASSIGNED'),
('TST_COMPLIANCE','TST_READ_ASSIGNED'),
('TST_FINANCE','TST_READ_ASSIGNED'),
('TST_FINANCE','TST_MANAGE_REFERENCE'),
('TST_TREASURY','TST_READ_ASSIGNED'),
('TST_TREASURY','TST_EXECUTE_PAYMENT'),
('TST_RECONCILER','TST_READ_ASSIGNED'),
('TST_RECONCILER','TST_RECONCILE_PAYMENT'),
('TST_AUDITOR','TST_READ_ASSIGNED'),
('TST_AUDITOR','TST_AUDIT_READ'),
('TST_TECH_ADMIN','TST_MANAGE_REFERENCE')
ON CONFLICT (role_code,permission_code) DO NOTHING;

CREATE OR REPLACE FUNCTION tst_private.has_active_permission(
  p_auth_user_id uuid,
  p_permission_code text,
  p_stewardship_entity_id uuid,
  p_organization_oid text,
  p_at timestamptz DEFAULT now()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, tst, tst_private, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM tst.participants p
    JOIN tst.role_assignments ra
      ON ra.participant_id = p.participant_id
     AND ra.stewardship_entity_id = p_stewardship_entity_id
     AND ra.organization_oid = p_organization_oid
    JOIN tst.role_permissions rp ON rp.role_code = ra.role_code
    JOIN tst.roles r ON r.role_code = ra.role_code AND r.is_active
    JOIN tst.permissions perm ON perm.permission_code = rp.permission_code
    WHERE p.auth_user_id = p_auth_user_id
      AND p.stewardship_entity_id = p_stewardship_entity_id
      AND p.organization_oid = p_organization_oid
      AND p.status = 'ACTIVE'
      AND p.effective_from <= p_at
      AND (p.effective_to IS NULL OR p.effective_to > p_at)
      AND ra.status = 'ACTIVE'
      AND ra.effective_from <= p_at
      AND (ra.effective_to IS NULL OR ra.effective_to > p_at)
      AND perm.permission_code = p_permission_code
  );
$$;

CREATE OR REPLACE FUNCTION tst_private.has_active_delegated_permission(
  p_auth_user_id uuid,
  p_permission_code text,
  p_stewardship_entity_id uuid,
  p_organization_oid text,
  p_at timestamptz DEFAULT now()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, tst, tst_private, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM tst.participants delegate_p
    JOIN tst.authority_delegations d
      ON d.delegate_participant_id = delegate_p.participant_id
     AND d.stewardship_entity_id = p_stewardship_entity_id
     AND d.organization_oid = p_organization_oid
    JOIN tst.participants delegator_p ON delegator_p.participant_id = d.delegator_participant_id
    WHERE delegate_p.auth_user_id = p_auth_user_id
      AND delegate_p.status = 'ACTIVE'
      AND delegator_p.status = 'ACTIVE'
      AND d.permission_code = p_permission_code
      AND d.status = 'ACTIVE'
      AND d.effective_from <= p_at
      AND d.effective_to > p_at
      AND tst_private.has_active_permission(
        delegator_p.auth_user_id,
        p_permission_code,
        p_stewardship_entity_id,
        p_organization_oid,
        p_at
      )
  );
$$;

ALTER TABLE tst.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.authority_delegations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON tst.participants, tst.role_assignments, tst.authority_delegations FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tst.participants, tst.role_assignments, tst.authority_delegations TO service_role;

CREATE POLICY participants_service_role_all ON tst.participants
  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY role_assignments_service_role_all ON tst.role_assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY authority_delegations_service_role_all ON tst.authority_delegations
  FOR ALL TO service_role USING (true) WITH CHECK (true);

REVOKE ALL ON FUNCTION tst_private.has_active_permission(uuid,text,uuid,text,timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION tst_private.has_active_delegated_permission(uuid,text,uuid,text,timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION tst_private.has_active_permission(uuid,text,uuid,text,timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.has_active_delegated_permission(uuid,text,uuid,text,timestamptz) TO service_role;

COMMENT ON TABLE tst.participants IS 'TST participant identity binding; auth_user_id is never derived from user-editable metadata.';
COMMENT ON TABLE tst.role_assignments IS 'Effective-dated organization-scoped TST role assignments and authority ceilings.';
COMMENT ON TABLE tst.authority_delegations IS 'Time-bounded delegated TST permission authority; delegation cannot exceed active delegator permission.';
