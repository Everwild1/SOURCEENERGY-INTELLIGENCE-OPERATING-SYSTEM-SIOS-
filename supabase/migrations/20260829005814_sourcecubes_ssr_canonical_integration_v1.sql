create schema if not exists sourcecubes;

create table if not exists sourcecubes.integration_spec (
  spec_id text primary key,
  name text not null,
  version text not null,
  status text not null default 'DRAFT',
  candidate_organization text,
  cohort_context text,
  canonical_registry text not null default 'public.ssr_spatial_registry',
  horizontal_registry text not null default 'ecology.ssr_dca_729_registry',
  vertical_registry text not null default 'ecology.ssr_vertical_11001_layers',
  w3w_reference_registry text not null default 'ecology.ssr_reference_addresses',
  namespace_policy text not null,
  evidence_policy text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcecubes.organization_candidates (
  candidate_id uuid primary key default gen_random_uuid(),
  candidate_name text not null,
  principal_name text,
  cohort_name text,
  candidate_status text not null default 'PENDING_EVIDENCE',
  organization_oid text references public.setc_organizations(oid),
  evidence_status text not null default 'UNVERIFIED',
  ip_status text not null default 'UNVERIFIED',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_name, cohort_name)
);

create table if not exists sourcecubes.cube_bindings (
  binding_id uuid primary key default gen_random_uuid(),
  cube_uid text not null unique,
  ssr_registry_id uuid references public.ssr_spatial_registry(id) on delete restrict,
  dca_sequence_no integer references ecology.ssr_dca_729_registry(sequence_no) on delete restrict,
  z_index integer not null,
  w3w_reference_id uuid references ecology.ssr_reference_addresses(id) on delete restrict,
  organization_oid text references public.setc_organizations(oid) on delete restrict,
  binding_status text not null default 'PENDING_CONCORDANCE',
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sourcecubes_z_index_valid check (z_index between -4000 and 7000)
);

create index if not exists sourcecubes_cube_bindings_dca_idx on sourcecubes.cube_bindings(dca_sequence_no);
create index if not exists sourcecubes_cube_bindings_z_idx on sourcecubes.cube_bindings(z_index);
create index if not exists sourcecubes_cube_bindings_org_idx on sourcecubes.cube_bindings(organization_oid);

insert into sourcecubes.integration_spec(spec_id,name,version,status,candidate_organization,cohort_context,namespace_policy,evidence_policy)
values ('SC-SSR-001','SourceCubes to SSR Canonical Integration','1.0','DRAFT_CONTROLLED','ELEO GDS / SourceCubes','OEJ Center Cohort One Candidate Register','SourceCube UID is an abstraction/binding over canonical SSR infrastructure. DCA coordinates remain distinct from canonical SSR addresses until explicit concordance.','No organization verification, IP ownership, W3W validation, DCA-to-SSR concordance, or cohort selection is inferred without supporting evidence.')
on conflict (spec_id) do update set updated_at=now();

insert into sourcecubes.organization_candidates(candidate_name,principal_name,cohort_name,candidate_status,evidence_status,ip_status,notes)
values ('ELEO GDS / SourceCubes','Octavia Jones','OEJ Center Cohort One','PENDING_INTAKE_AND_VERIFICATION','UNVERIFIED','UNVERIFIED','Candidate register linkage only; no selection, endorsement, funding, equity, organization verification, or IP determination asserted.')
on conflict (candidate_name,cohort_name) do update set principal_name=excluded.principal_name, updated_at=now();

comment on schema sourcecubes is 'Governed SourceCubes interoperability layer over canonical SourceEnergy SSR infrastructure.';
comment on table sourcecubes.cube_bindings is 'Concordance table only. A row must not be treated as proof of DCA-to-SSR or W3W equivalence without evidence_reference and an appropriate binding_status.';
