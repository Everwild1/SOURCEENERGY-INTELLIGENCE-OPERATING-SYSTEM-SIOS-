-- HEI-BUILD-001 / issues #143 and #152
-- Canonical SETC identity promotion + HEI institutional/consortium foundation.

CREATE TABLE IF NOT EXISTS public.setc_organizations (
  oid text PRIMARY KEY CHECK (oid ~ '^SETC-OID-[0-9a-f]{32}$'),
  legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
  normalized_name text NOT NULL,
  organization_type text NOT NULL,
  verification_state text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_state IN ('UNVERIFIED','PENDING_VERIFICATION','VERIFIED','ENHANCED_VERIFICATION','ACCREDITED','SUSPENDED','REVOKED','ARCHIVED')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived_at timestamptz
);
CREATE INDEX IF NOT EXISTS setc_organizations_normalized_name_idx ON public.setc_organizations(normalized_name);

CREATE TABLE IF NOT EXISTS public.setc_organization_aliases (
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE CASCADE,
  alias text NOT NULL CHECK (length(btrim(alias)) > 0), normalized_alias text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (organization_oid, normalized_alias)
);
CREATE INDEX IF NOT EXISTS setc_organization_alias_lookup_idx ON public.setc_organization_aliases(normalized_alias);

CREATE TABLE IF NOT EXISTS public.setc_organization_external_ids (
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid) ON DELETE CASCADE,
  namespace text NOT NULL, external_id text NOT NULL, source text, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(namespace, external_id), UNIQUE(organization_oid, namespace, external_id)
);

CREATE TABLE IF NOT EXISTS public.setc_organization_relationships (
  relationship_id text PRIMARY KEY,
  source_organization_id text NOT NULL REFERENCES public.setc_organizations(oid),
  target_organization_id text NOT NULL REFERENCES public.setc_organizations(oid),
  relationship_type text NOT NULL,
  state text NOT NULL DEFAULT 'ASSERTED', effective_from timestamptz, effective_to timestamptz,
  evidence_reference text, asserted_by text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(source_organization_id <> target_organization_id), CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS public.hei_institution_profiles (
  organization_oid text PRIMARY KEY REFERENCES public.setc_organizations(oid),
  institution_category text NOT NULL DEFAULT 'HIGHER_EDUCATION',
  qualification_state text NOT NULL DEFAULT 'IDENTIFIED' CHECK (qualification_state IN ('IDENTIFIED','VERIFIED','QUALIFIED','INTEGRATED','STRATEGIC_ANCHOR','SUSPENDED')),
  qualification_tier text, jurisdiction text, accreditation_summary text, primary_domain text,
  data_classification text NOT NULL DEFAULT 'CONFIDENTIAL' CHECK (data_classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED','HIGHLY_RESTRICTED')),
  evidence_reference text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hei_institution_designations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  designation_type text NOT NULL CHECK (designation_type IN ('HBCU','HSI','MSI','PBI','TCU','AANAPISI','NASNTI','OTHER')),
  designation_state text NOT NULL DEFAULT 'ASSERTED' CHECK (designation_state IN ('ASSERTED','PENDING_VERIFICATION','VERIFIED','SUSPENDED','EXPIRED','REVOKED')),
  evidence_reference text, effective_from timestamptz, effective_to timestamptz, verified_at timestamptz, verified_by text,
  UNIQUE(organization_oid, designation_type, effective_from), CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS public.hei_consortia (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, consortium_code text NOT NULL UNIQUE, name text NOT NULL,
  purpose text, charter_reference text, status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','ACTIVE','SUSPENDED','CLOSED')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hei_consortium_memberships (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  consortium_id bigint NOT NULL REFERENCES public.hei_consortia(id), organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  membership_class text NOT NULL CHECK(membership_class IN ('OBSERVER','MEMBER','PARTICIPATING_INSTITUTION','STRATEGIC_ANCHOR','CONSORTIUM_PARTNER')),
  state text NOT NULL DEFAULT 'PROPOSED' CHECK(state IN ('PROPOSED','DUE_DILIGENCE','APPROVED','ACTIVE','SUSPENDED','WITHDRAWN','TERMINATED')),
  effective_from timestamptz, effective_to timestamptz, evidence_reference text, approved_by text, approved_at timestamptz,
  UNIQUE(consortium_id, organization_oid), CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS public.hei_reserved_powers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_oid text NOT NULL REFERENCES public.setc_organizations(oid),
  power_code text NOT NULL, retained boolean NOT NULL DEFAULT true, delegation_prohibited boolean NOT NULL DEFAULT true,
  governance_reference text, evidence_reference text, effective_from timestamptz NOT NULL DEFAULT now(), effective_to timestamptz,
  UNIQUE(organization_oid, power_code, effective_from)
);

CREATE TABLE IF NOT EXISTS public.hei_shared_services (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, consortium_id bigint NOT NULL REFERENCES public.hei_consortia(id),
  service_code text NOT NULL, name text NOT NULL, provider_organization_oid text REFERENCES public.setc_organizations(oid),
  data_classification text NOT NULL DEFAULT 'INTERNAL', status text NOT NULL DEFAULT 'ACTIVE', UNIQUE(consortium_id, service_code)
);

CREATE TABLE IF NOT EXISTS public.hei_service_entitlements (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, service_id bigint NOT NULL REFERENCES public.hei_shared_services(id),
  organization_oid text NOT NULL REFERENCES public.setc_organizations(oid), permitted_scope text NOT NULL DEFAULT 'STANDARD',
  state text NOT NULL DEFAULT 'PROPOSED' CHECK(state IN ('PROPOSED','APPROVED','ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
  effective_from timestamptz, effective_to timestamptz, authority_reference text, evidence_reference text,
  UNIQUE(service_id, organization_oid), CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

-- Default-deny for authenticated/anon clients. Governed server-side operations use service_role.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['setc_organizations','setc_organization_aliases','setc_organization_external_ids','setc_organization_relationships','hei_institution_profiles','hei_institution_designations','hei_consortia','hei_consortium_memberships','hei_reserved_powers','hei_shared_services','hei_service_entitlements']
  LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t); END LOOP;
END $$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['setc_organizations','setc_organization_aliases','setc_organization_external_ids','setc_organization_relationships','hei_institution_profiles','hei_institution_designations','hei_consortia','hei_consortium_memberships','hei_reserved_powers','hei_shared_services','hei_service_entitlements']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_service_role_all', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)', t || '_service_role_all', t);
  END LOOP;
END $$;

COMMENT ON TABLE public.hei_institution_designations IS 'Multi-valued institutional designation registry; designation evidence does not itself create legal status.';
COMMENT ON TABLE public.hei_consortium_memberships IS 'Consortium membership does not transfer institutional fiduciary authority, ownership, or blanket service/data access.';
COMMENT ON TABLE public.hei_service_entitlements IS 'Shared-service access is explicit and separate from consortium membership.';
