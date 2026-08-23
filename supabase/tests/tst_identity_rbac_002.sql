-- TST-WP02 identity/RBAC contract tests.
BEGIN;

DO $$
DECLARE
  rls_count integer;
BEGIN
  IF to_regclass('tst.participants') IS NULL THEN RAISE EXCEPTION 'missing tst.participants'; END IF;
  IF to_regclass('tst.role_assignments') IS NULL THEN RAISE EXCEPTION 'missing tst.role_assignments'; END IF;
  IF to_regclass('tst.authority_delegations') IS NULL THEN RAISE EXCEPTION 'missing tst.authority_delegations'; END IF;

  SELECT count(*) INTO rls_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='tst'
    AND c.relname IN ('participants','role_assignments','authority_delegations')
    AND c.relrowsecurity;
  IF rls_count <> 3 THEN RAISE EXCEPTION 'WP02 RLS incomplete: %/3', rls_count; END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema='tst'
      AND table_name IN ('participants','role_assignments','authority_delegations')
      AND grantee IN ('anon','authenticated')
  ) THEN RAISE EXCEPTION 'client roles unexpectedly granted WP02 private tables'; END IF;
END $$;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES
('SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','TST RBAC Org A','tst rbac org a','FOUNDATION','VERIFIED'),
('SETC-OID-ffffffffffffffffffffffffffffffff','TST RBAC Org B','tst rbac org b','FOUNDATION','VERIFIED')
ON CONFLICT (oid) DO NOTHING;

INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from)
VALUES
('SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','TST-RBAC-A','TST RBAC Org A','ACTIVE','2026-08-23'),
('SETC-OID-ffffffffffffffffffffffffffffffff','TST-RBAC-B','TST RBAC Org B','ACTIVE','2026-08-23')
ON CONFLICT (organization_oid) DO NOTHING;

DO $$
DECLARE
  entity_a uuid;
  entity_b uuid;
  trustee_user uuid := '11111111-1111-1111-1111-111111111111';
  expired_user uuid := '22222222-2222-2222-2222-222222222222';
  suspended_user uuid := '33333333-3333-3333-3333-333333333333';
  unassigned_user uuid := '44444444-4444-4444-4444-444444444444';
  trustee_participant uuid;
BEGIN
  SELECT stewardship_entity_id INTO entity_a FROM tst.stewardship_entities WHERE stewardship_code='TST-RBAC-A';
  SELECT stewardship_entity_id INTO entity_b FROM tst.stewardship_entities WHERE stewardship_code='TST-RBAC-B';

  INSERT INTO tst.participants(stewardship_entity_id,organization_oid,auth_user_id,display_name,status,effective_from)
  VALUES
  (entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',trustee_user,'Active Trustee','ACTIVE','2026-08-01'),
  (entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',expired_user,'Expired Trustee','ACTIVE','2026-07-01'),
  (entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',suspended_user,'Suspended Trustee','SUSPENDED','2026-08-01'),
  (entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',unassigned_user,'Unassigned User','ACTIVE','2026-08-01');

  SELECT participant_id INTO trustee_participant FROM tst.participants WHERE auth_user_id=trustee_user;

  INSERT INTO tst.role_assignments(participant_id,stewardship_entity_id,organization_oid,role_code,status,effective_from)
  SELECT participant_id,entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','TST_TRUSTEE','ACTIVE','2026-08-01'
  FROM tst.participants WHERE auth_user_id=trustee_user;

  INSERT INTO tst.role_assignments(participant_id,stewardship_entity_id,organization_oid,role_code,status,effective_from,effective_to)
  SELECT participant_id,entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','TST_TRUSTEE','ACTIVE','2026-07-01','2026-08-01'
  FROM tst.participants WHERE auth_user_id=expired_user;

  INSERT INTO tst.role_assignments(participant_id,stewardship_entity_id,organization_oid,role_code,status,effective_from)
  SELECT participant_id,entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','TST_TRUSTEE','ACTIVE','2026-08-01'
  FROM tst.participants WHERE auth_user_id=suspended_user;

  IF NOT tst_private.has_active_permission(trustee_user,'TST_APPROVE_FIDUCIARY',entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','2026-08-23') THEN
    RAISE EXCEPTION 'active trustee permission unexpectedly denied';
  END IF;
  IF tst_private.has_active_permission(trustee_user,'TST_APPROVE_FIDUCIARY',entity_b,'SETC-OID-ffffffffffffffffffffffffffffffff','2026-08-23') THEN
    RAISE EXCEPTION 'cross-organization permission unexpectedly granted';
  END IF;
  IF tst_private.has_active_permission(expired_user,'TST_APPROVE_FIDUCIARY',entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','2026-08-23') THEN
    RAISE EXCEPTION 'expired assignment unexpectedly authorized';
  END IF;
  IF tst_private.has_active_permission(suspended_user,'TST_APPROVE_FIDUCIARY',entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','2026-08-23') THEN
    RAISE EXCEPTION 'suspended participant unexpectedly authorized';
  END IF;
  IF tst_private.has_active_permission(unassigned_user,'TST_APPROVE_FIDUCIARY',entity_a,'SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','2026-08-23') THEN
    RAISE EXCEPTION 'unassigned participant unexpectedly authorized';
  END IF;
END $$;

-- User-editable metadata must not be referenced by the authorization functions.
DO $$
DECLARE
  fn text;
BEGIN
  SELECT pg_get_functiondef('tst_private.has_active_permission(uuid,text,uuid,text,timestamptz)'::regprocedure) INTO fn;
  IF lower(fn) LIKE '%user_metadata%' OR lower(fn) LIKE '%raw_user_meta_data%' THEN
    RAISE EXCEPTION 'authorization function references user-editable metadata';
  END IF;
END $$;

ROLLBACK;
