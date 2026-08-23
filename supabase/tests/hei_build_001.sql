-- HEI-BUILD-001 database contract tests. Run after migrations in a disposable/test DB.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.setc_organizations') IS NULL THEN RAISE EXCEPTION 'missing canonical setc_organizations'; END IF;
  IF to_regclass('public.hei_institution_profiles') IS NULL THEN RAISE EXCEPTION 'missing hei_institution_profiles'; END IF;
  IF to_regclass('public.hei_institution_designations') IS NULL THEN RAISE EXCEPTION 'missing hei_institution_designations'; END IF;
  IF to_regclass('public.hei_consortium_memberships') IS NULL THEN RAISE EXCEPTION 'missing hei_consortium_memberships'; END IF;
  IF to_regclass('public.hei_service_entitlements') IS NULL THEN RAISE EXCEPTION 'missing hei_service_entitlements'; END IF;
END $$;

-- Multiple designations are permitted for the same canonical institution.
INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','Test University','test university','UNIVERSITY','VERIFIED');
INSERT INTO public.hei_institution_profiles(organization_oid) VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO public.hei_institution_designations(organization_oid,designation_type,designation_state,effective_from)
VALUES
('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','HBCU','VERIFIED','2026-01-01'),
('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','MSI','VERIFIED','2026-01-01');

-- Membership and service entitlement are intentionally separate.
INSERT INTO public.hei_consortia(consortium_code,name,status) VALUES ('TEST','Test Consortium','ACTIVE');
INSERT INTO public.hei_consortium_memberships(consortium_id,organization_oid,membership_class,state)
SELECT id,'SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','PARTICIPATING_INSTITUTION','ACTIVE' FROM public.hei_consortia WHERE consortium_code='TEST';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.hei_service_entitlements e
    JOIN public.hei_shared_services s ON s.id=e.service_id
    JOIN public.hei_consortia c ON c.id=s.consortium_id
    WHERE c.consortium_code='TEST' AND e.organization_oid='SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) THEN RAISE EXCEPTION 'membership silently created service entitlement'; END IF;
END $$;

-- Reserved powers default to retained and delegation prohibited.
INSERT INTO public.hei_reserved_powers(organization_oid,power_code)
VALUES ('SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','ENDOWMENT_CONTROL');
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.hei_reserved_powers WHERE organization_oid='SETC-OID-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' AND power_code='ENDOWMENT_CONTROL' AND retained AND delegation_prohibited)
  THEN RAISE EXCEPTION 'reserved power defaults violated'; END IF;
END $$;

-- RLS must be enabled on protected HEI tables.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('hei_institution_profiles','hei_institution_designations','hei_consortium_memberships','hei_reserved_powers','hei_service_entitlements') AND NOT c.relrowsecurity
  ) THEN RAISE EXCEPTION 'HEI protected table without RLS'; END IF;
END $$;

ROLLBACK;
