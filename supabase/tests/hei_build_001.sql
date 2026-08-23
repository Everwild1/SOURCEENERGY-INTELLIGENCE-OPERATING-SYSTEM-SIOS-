-- HEI-BUILD-001 database contract tests. Run after migrations in a disposable/test DB.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.setc_organizations') IS NULL THEN RAISE EXCEPTION 'missing canonical setc_organizations'; END IF;
  IF to_regclass('public.setc_organization_aliases') IS NULL THEN RAISE EXCEPTION 'missing setc_organization_aliases'; END IF;
  IF to_regclass('public.setc_organization_capabilities') IS NULL THEN RAISE EXCEPTION 'missing setc_organization_capabilities'; END IF;
  IF to_regclass('public.setc_organization_external_ids') IS NULL THEN RAISE EXCEPTION 'missing setc_organization_external_ids'; END IF;
  IF to_regclass('public.setc_organization_relationships') IS NULL THEN RAISE EXCEPTION 'missing setc_organization_relationships'; END IF;
  IF to_regclass('public.setc_organization_relationship_history') IS NULL THEN RAISE EXCEPTION 'missing setc_organization_relationship_history'; END IF;
  IF to_regclass('public.hei_institution_profiles') IS NULL THEN RAISE EXCEPTION 'missing hei_institution_profiles'; END IF;
  IF to_regclass('public.hei_institution_designations') IS NULL THEN RAISE EXCEPTION 'missing hei_institution_designations'; END IF;
  IF to_regclass('public.hei_consortium_memberships') IS NULL THEN RAISE EXCEPTION 'missing hei_consortium_memberships'; END IF;
  IF to_regclass('public.hei_service_entitlements') IS NULL THEN RAISE EXCEPTION 'missing hei_service_entitlements'; END IF;
END $$;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES
('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','Test University','test university','UNIVERSITY','VERIFIED'),
('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','Test Research Partner','test research partner','RESEARCH_INSTITUTE','VERIFIED');

-- Canonical identity extensions resolve to the same OID rather than creating parallel masters.
INSERT INTO public.setc_organization_aliases(organization_oid,alias,normalized_alias)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','TU','tu');
INSERT INTO public.setc_organization_capabilities(organization_oid,capability)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','HIGHER_EDUCATION');
INSERT INTO public.setc_organization_external_ids(organization_oid,namespace,external_id,source)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','UNITID','999999','TEST');

INSERT INTO public.setc_organization_relationships(
  relationship_id,source_organization_id,target_organization_id,relationship_type,state,effective_from,evidence_reference
) VALUES (
  'REL-HEI-001','SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'RESEARCHES_WITH','VERIFIED','2026-01-01','test:evidence'
);
INSERT INTO public.setc_organization_relationship_history(relationship_id,prior_state,new_state,reason)
VALUES ('REL-HEI-001','PENDING_VERIFICATION','VERIFIED','contract test');

-- Multiple designations are permitted for the same canonical institution.
INSERT INTO public.hei_institution_profiles(organization_oid)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO public.hei_institution_designations(organization_oid,designation_type,designation_state,effective_from)
VALUES
('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','HBCU','VERIFIED','2026-01-01'),
('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','MSI','VERIFIED','2026-01-01');

-- Membership and service entitlement are intentionally separate.
INSERT INTO public.hei_consortia(consortium_code,name,status) VALUES ('TEST','Test Consortium','ACTIVE');
INSERT INTO public.hei_consortium_memberships(consortium_id,organization_oid,membership_class,state)
SELECT id,'SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','PARTICIPATING_INSTITUTION','ACTIVE'
FROM public.hei_consortia WHERE consortium_code='TEST';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.hei_service_entitlements e
    JOIN public.hei_shared_services s ON s.id=e.service_id
    JOIN public.hei_consortia c ON c.id=s.consortium_id
    WHERE c.consortium_code='TEST'
      AND e.organization_oid='SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) THEN RAISE EXCEPTION 'membership silently created service entitlement'; END IF;
END $$;

-- Reserved powers default to retained and delegation prohibited.
INSERT INTO public.hei_reserved_powers(organization_oid,power_code)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','ENDOWMENT_CONTROL');
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.hei_reserved_powers
    WHERE organization_oid='SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      AND power_code='ENDOWMENT_CONTROL' AND retained AND delegation_prohibited
  ) THEN RAISE EXCEPTION 'reserved power defaults violated'; END IF;
END $$;

-- All Wave-1 identity and HEI tables must have RLS enabled.
DO $$
DECLARE expected_count integer := 13; protected_count integer; enabled_count integer;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE c.relrowsecurity)
    INTO protected_count, enabled_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname = ANY(ARRAY[
    'setc_organizations','setc_organization_aliases','setc_organization_capabilities',
    'setc_organization_external_ids','setc_organization_relationships','setc_organization_relationship_history',
    'hei_institution_profiles','hei_institution_designations','hei_consortia','hei_consortium_memberships',
    'hei_reserved_powers','hei_shared_services','hei_service_entitlements'
  ]);
  IF protected_count <> expected_count THEN RAISE EXCEPTION 'expected % protected tables, found %', expected_count, protected_count; END IF;
  IF enabled_count <> expected_count THEN RAISE EXCEPTION 'RLS not enabled on all Wave-1 tables: %/%', enabled_count, expected_count; END IF;
END $$;

-- Invalid relationship type/state must be rejected by the schema.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.setc_organization_relationships(
      relationship_id,source_organization_id,target_organization_id,relationship_type,state
    ) VALUES (
      'REL-INVALID','SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'UNCONTROLLED_TYPE','ACTIVE'
    );
    RAISE EXCEPTION 'invalid relationship type accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

ROLLBACK;
