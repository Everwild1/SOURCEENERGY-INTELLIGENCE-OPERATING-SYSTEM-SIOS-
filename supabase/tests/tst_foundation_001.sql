-- TST-WP01 foundation database contract tests.
-- Run after canonical SETC organization migration + TST foundation migration.
BEGIN;

DO $$
DECLARE
  missing_schema text;
BEGIN
  SELECT s INTO missing_schema
  FROM unnest(ARRAY['tst','tst_private','tst_audit','tst_reporting','tst_public','tst_api']) s
  WHERE NOT EXISTS (SELECT 1 FROM pg_namespace n WHERE n.nspname = s)
  LIMIT 1;
  IF missing_schema IS NOT NULL THEN
    RAISE EXCEPTION 'missing TST schema: %', missing_schema;
  END IF;

  IF to_regclass('tst.stewardship_entities') IS NULL THEN RAISE EXCEPTION 'missing tst.stewardship_entities'; END IF;
  IF to_regclass('tst.funds') IS NULL THEN RAISE EXCEPTION 'missing tst.funds'; END IF;
  IF to_regclass('tst.roles') IS NULL THEN RAISE EXCEPTION 'missing tst.roles'; END IF;
  IF to_regclass('tst.permissions') IS NULL THEN RAISE EXCEPTION 'missing tst.permissions'; END IF;
  IF to_regclass('tst.feature_flags') IS NULL THEN RAISE EXCEPTION 'missing tst.feature_flags'; END IF;
END $$;

-- Canonical identity binding: TST entity must reference the existing SETC organization master.
INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-cccccccccccccccccccccccccccccccc','TST Test Stewardship Entity','tst test stewardship entity','FOUNDATION','VERIFIED')
ON CONFLICT (oid) DO NOTHING;

INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from)
VALUES ('SETC-OID-cccccccccccccccccccccccccccccccc','TST-TEST','TST Test Stewardship Entity','ACTIVE','2026-08-23');

INSERT INTO tst.funds(stewardship_entity_id,fund_code,name,purpose,currency,fund_type,status,authorized_ceiling)
SELECT stewardship_entity_id,'TITHE-USD','Tithe Stewardship Fund','Controlled tithe stewardship','USD','TITHE','ACTIVE',1000000.00
FROM tst.stewardship_entities WHERE stewardship_code='TST-TEST';

DO $$
DECLARE
  rls_count integer;
  numeric_type text;
  enabled_count integer;
BEGIN
  SELECT count(*) INTO rls_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='tst' AND c.relname IN ('stewardship_entities','funds','roles','permissions','role_permissions','feature_flags')
    AND c.relrowsecurity;
  IF rls_count <> 6 THEN RAISE EXCEPTION 'TST foundation RLS incomplete: %/6', rls_count; END IF;

  SELECT format_type(a.atttypid,a.atttypmod) INTO numeric_type
  FROM pg_attribute a
  WHERE a.attrelid='tst.funds'::regclass AND a.attname='authorized_ceiling';
  IF numeric_type <> 'numeric(20,2)' THEN RAISE EXCEPTION 'financial precision contract failed: %', numeric_type; END IF;

  SELECT count(*) INTO enabled_count FROM tst.feature_flags
  WHERE feature_code IN ('TST_DIGITAL_ASSETS','TST_SOURCE_COIN','TST_SBLC','TST_INTERNATIONAL_BENEFICIARIES')
    AND activation_state='DISABLED';
  IF enabled_count <> 4 THEN RAISE EXCEPTION 'high-risk feature flags are not disabled'; END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema='tst' AND grantee IN ('anon','authenticated')
  ) THEN RAISE EXCEPTION 'anon/authenticated unexpectedly granted TST foundation table privileges'; END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.usage_privileges
    WHERE object_type='SCHEMA' AND object_name IN ('tst_private','tst_audit')
      AND grantee IN ('anon','authenticated')
  ) THEN RAISE EXCEPTION 'private/audit schema unexpectedly exposed'; END IF;
END $$;

-- FK must reject an invented/non-canonical organization.
DO $$
BEGIN
  BEGIN
    INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name)
    VALUES ('SETC-OID-dddddddddddddddddddddddddddddddd','TST-INVALID','Invalid Entity');
    RAISE EXCEPTION 'canonical organization FK did not reject invalid organization';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END $$;

ROLLBACK;
