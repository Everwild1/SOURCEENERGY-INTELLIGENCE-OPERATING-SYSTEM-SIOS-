-- TST-WP01 / issues #162 and #163
-- Tithe Stewardship Trust foundation: bounded schemas, canonical identity binding,
-- governed feature flags, role vocabulary, and deny-by-default RLS baseline.
-- NOTE: future migrations should be generated with the installed Supabase CLI.
-- This repository activation migration follows the repository's existing timestamped convention.

CREATE SCHEMA IF NOT EXISTS tst;
CREATE SCHEMA IF NOT EXISTS tst_private;
CREATE SCHEMA IF NOT EXISTS tst_audit;
CREATE SCHEMA IF NOT EXISTS tst_reporting;
CREATE SCHEMA IF NOT EXISTS tst_public;
CREATE SCHEMA IF NOT EXISTS tst_api;

REVOKE ALL ON SCHEMA tst FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA tst_private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA tst_audit FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA tst_reporting FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA tst_public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA tst_api FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SCHEMA tst, tst_private, tst_audit, tst_reporting, tst_public, tst_api TO service_role;

CREATE TABLE IF NOT EXISTS tst.stewardship_entities (
  stewardship_entity_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_oid text NOT NULL UNIQUE REFERENCES public.setc_organizations(oid) ON DELETE RESTRICT,
  stewardship_code text NOT NULL UNIQUE CHECK (stewardship_code ~ '^TST-[A-Z0-9][A-Z0-9_-]{2,63}$'),
  legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','ACTIVE','SUSPENDED','TERMINATED','ARCHIVED')),
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);
CREATE INDEX IF NOT EXISTS tst_stewardship_entities_org_idx ON tst.stewardship_entities(organization_oid, status);

CREATE TABLE IF NOT EXISTS tst.funds (
  fund_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  fund_code text NOT NULL,
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  purpose text NOT NULL,
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  fund_type text NOT NULL DEFAULT 'TITHE' CHECK (fund_type IN ('TITHE','RESTRICTED','DESIGNATED','OPERATING_STEWARDSHIP')),
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','CLOSED','ARCHIVED')),
  authorized_ceiling numeric(20,2) CHECK (authorized_ceiling IS NULL OR authorized_ceiling >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (stewardship_entity_id, fund_code)
);
CREATE INDEX IF NOT EXISTS tst_funds_entity_status_idx ON tst.funds(stewardship_entity_id, status);

CREATE TABLE IF NOT EXISTS tst.roles (
  role_code text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  is_fiduciary boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tst.permissions (
  permission_code text PRIMARY KEY,
  description text NOT NULL,
  risk_tier text NOT NULL DEFAULT 'STANDARD' CHECK (risk_tier IN ('STANDARD','ELEVATED','HIGH','CRITICAL')),
  requires_aal2 boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tst.role_permissions (
  role_code text NOT NULL REFERENCES tst.roles(role_code) ON DELETE RESTRICT,
  permission_code text NOT NULL REFERENCES tst.permissions(permission_code) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_code, permission_code)
);

CREATE TABLE IF NOT EXISTS tst.feature_flags (
  feature_code text PRIMARY KEY,
  activation_state text NOT NULL CHECK (activation_state IN ('DISABLED','TEST','PILOT','ENABLED')),
  rationale text NOT NULL,
  approved_by_reference text,
  approved_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO tst.roles(role_code,name,description,is_fiduciary) VALUES
('TST_TRUSTEE','Trustee','Governance/trustee authority',true),
('TST_PROGRAM_OFFICER','Program Officer','Program and beneficiary workflow role',false),
('TST_COMPLIANCE','Compliance','Compliance and screening role',false),
('TST_FINANCE','Finance','Financial review role',false),
('TST_TREASURY','Treasury','Payment execution role',false),
('TST_RECONCILER','Reconciler','Independent reconciliation role',false),
('TST_AUDITOR','Auditor','Read/assurance role',false),
('TST_TECH_ADMIN','Technical Administrator','Technical operations without fiduciary authority',false)
ON CONFLICT (role_code) DO NOTHING;

INSERT INTO tst.permissions(permission_code,description,risk_tier,requires_aal2) VALUES
('TST_READ_ASSIGNED','Read authorized TST records','STANDARD',false),
('TST_MANAGE_REFERENCE','Manage governed reference data','ELEVATED',true),
('TST_APPROVE_FIDUCIARY','Approve fiduciary transaction','CRITICAL',true),
('TST_EXECUTE_PAYMENT','Execute approved payment','CRITICAL',true),
('TST_RECONCILE_PAYMENT','Reconcile settlement independently','HIGH',true),
('TST_AUDIT_READ','Read assurance/audit records','ELEVATED',true)
ON CONFLICT (permission_code) DO NOTHING;

INSERT INTO tst.feature_flags(feature_code,activation_state,rationale) VALUES
('TST_CORE','PILOT','Foundation enabled only for controlled TST pilot'),
('TST_PAYMENTS','PILOT','Fiat payment workflow limited to controlled pilot'),
('TST_PUBLIC_REPORTING','DISABLED','Requires publication/privacy certification'),
('TST_INTERNATIONAL_BENEFICIARIES','DISABLED','Requires separate cross-border compliance gate'),
('TST_DIGITAL_ASSETS','DISABLED','Excluded from initial pilot'),
('TST_SOURCE_COIN','DISABLED','Requires separate Source Coin governance activation'),
('TST_SBLC','DISABLED','Excluded from initial TST pilot')
ON CONFLICT (feature_code) DO NOTHING;

ALTER TABLE tst.stewardship_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.feature_flags ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA tst FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tst TO service_role;

CREATE POLICY stewardship_entities_service_role_all ON tst.stewardship_entities FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY funds_service_role_all ON tst.funds FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY roles_service_role_all ON tst.roles FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY permissions_service_role_all ON tst.permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY role_permissions_service_role_all ON tst.role_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY feature_flags_service_role_all ON tst.feature_flags FOR ALL TO service_role USING (true) WITH CHECK (true);

ALTER DEFAULT PRIVILEGES IN SCHEMA tst REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA tst REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA tst REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA tst_private REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA tst_audit REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;

COMMENT ON SCHEMA tst IS 'TST governed operational stewardship domain; private by default.';
COMMENT ON SCHEMA tst_private IS 'TST high-sensitivity/private domain; not a client API surface.';
COMMENT ON SCHEMA tst_audit IS 'TST append-oriented audit and assurance domain.';
COMMENT ON SCHEMA tst_reporting IS 'TST governed internal reporting domain.';
COMMENT ON SCHEMA tst_public IS 'TST explicitly approved D0 public transparency boundary.';
COMMENT ON SCHEMA tst_api IS 'TST deliberately exposed controlled API/RPC boundary.';
