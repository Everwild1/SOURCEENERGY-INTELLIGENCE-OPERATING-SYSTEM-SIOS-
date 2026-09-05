-- JLC-001 Jamaica Logistics Corridor integration.
-- Private operational registry linking canonical SETC organizations to Jamaica
-- logistics nodes, programs, and evidence without asserting legal authority.

create schema if not exists jlc;
comment on schema jlc is 'Private Jamaica Logistics Corridor registry. Records operating architecture and evidence references; they do not independently establish contracts, concessions, permits, land rights, financing, or government authority.';

create table if not exists jlc.corridors (
  corridor_code text primary key,
  name text not null,
  jurisdiction_code text not null default 'JM',
  corridor_type text not null check (corridor_type in ('MULTIMODAL','PORT_LOGISTICS','SEZ_LOGISTICS','COLD_CHAIN','OTHER')),
  lifecycle_state text not null default 'PLANNING' check (lifecycle_state in ('CONCEPT','PLANNING','DILIGENCE','PROCUREMENT','OPERATING','SUSPENDED','CLOSED')),
  description text,
  governance_reference text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists jlc.nodes (
  node_code text primary key,
  name text not null,
  node_type text not null check (node_type in ('PORT','NEAR_PORT','SEZ','RAIL','AIR','WAREHOUSE','CROSS_DOCK','DISTRIBUTION','OTHER')),
  locality text,
  jurisdiction_code text not null default 'JM',
  latitude double precision,
  longitude double precision,
  lifecycle_state text not null default 'IDENTIFIED' check (lifecycle_state in ('IDENTIFIED','PLANNING','DILIGENCE','PROCUREMENT','OPERATING','SUSPENDED','RETIRED')),
  external_spatial_reference text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create table if not exists jlc.corridor_nodes (
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  node_code text not null references jlc.nodes(node_code) on delete restrict,
  sequence_no integer not null check (sequence_no > 0),
  node_role text not null,
  status text not null default 'PLANNED' check (status in ('PLANNED','ACTIVE','SUSPENDED','RETIRED')),
  evidence_reference text,
  primary key (corridor_code, node_code)
);

create table if not exists jlc.programs (
  program_code text primary key,
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  name text not null,
  program_type text not null check (program_type in ('RAIL_ACTIVATION','COLD_CHAIN','PORT_EXPANSION','SEZ_PARTICIPATION','WAREHOUSING','AUTOMOTIVE_LOGISTICS','OTHER')),
  lifecycle_state text not null default 'PLANNING' check (lifecycle_state in ('CONCEPT','PLANNING','DILIGENCE','PROCUREMENT','PILOT','OPERATING','SUSPENDED','CLOSED')),
  description text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists jlc.corridor_organizations (
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  relationship_role text not null,
  verification_state text not null default 'ASSERTED' check (verification_state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','REJECTED','ARCHIVED')),
  evidence_reference text,
  primary key (corridor_code, organization_oid, relationship_role)
);

create table if not exists jlc.program_organizations (
  program_code text not null references jlc.programs(program_code) on delete cascade,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  relationship_role text not null,
  verification_state text not null default 'ASSERTED' check (verification_state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','REJECTED','ARCHIVED')),
  evidence_reference text,
  primary key (program_code, organization_oid, relationship_role)
);

create table if not exists jlc.evidence_links (
  evidence_code text primary key,
  subject_type text not null check (subject_type in ('CORRIDOR','NODE','PROGRAM','ORGANIZATION_LINK')),
  subject_reference text not null,
  title text not null,
  source_system text not null,
  source_uri text not null,
  evidence_class text not null default 'REFERENCE' check (evidence_class in ('REFERENCE','INTERNAL_DOCUMENT','OFFICIAL_SOURCE','CONTRACT_EVIDENCE','FINANCING_EVIDENCE','OTHER')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING','EVIDENCE_SUPPORTED','VERIFIED_REFERENCE','CONFLICT','STALE','REJECTED')),
  observed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists jlc_corridor_nodes_sequence_idx on jlc.corridor_nodes(corridor_code, sequence_no);
create index if not exists jlc_programs_corridor_idx on jlc.programs(corridor_code);
create index if not exists jlc_corridor_org_oid_idx on jlc.corridor_organizations(organization_oid);
create index if not exists jlc_program_org_oid_idx on jlc.program_organizations(organization_oid);
create index if not exists jlc_evidence_subject_idx on jlc.evidence_links(subject_type, subject_reference);

alter table jlc.corridors enable row level security;
alter table jlc.nodes enable row level security;
alter table jlc.corridor_nodes enable row level security;
alter table jlc.programs enable row level security;
alter table jlc.corridor_organizations enable row level security;
alter table jlc.program_organizations enable row level security;
alter table jlc.evidence_links enable row level security;

grant usage on schema jlc to service_role;
grant select, insert, update, delete on all tables in schema jlc to service_role;
revoke all on schema jlc from anon, authenticated;
revoke all on all tables in schema jlc from anon, authenticated;

create policy service_role_all on jlc.corridors for all to service_role using (true) with check (true);
create policy service_role_all on jlc.nodes for all to service_role using (true) with check (true);
create policy service_role_all on jlc.corridor_nodes for all to service_role using (true) with check (true);
create policy service_role_all on jlc.programs for all to service_role using (true) with check (true);
create policy service_role_all on jlc.corridor_organizations for all to service_role using (true) with check (true);
create policy service_role_all on jlc.program_organizations for all to service_role using (true) with check (true);
create policy service_role_all on jlc.evidence_links for all to service_role using (true) with check (true);

insert into jlc.corridors (corridor_code, name, corridor_type, lifecycle_state, description, evidence_reference)
values (
  'JLC-001',
  'SourceEnergy Jamaica Logistics Corridor',
  'MULTIMODAL',
  'PLANNING',
  'Kingston-centered multimodal logistics architecture integrating near-port, SEZ, rail, truck, cold-chain, and regional trade interfaces.',
  'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
)
on conflict (corridor_code) do nothing;

insert into jlc.nodes (node_code, name, node_type, locality, lifecycle_state, evidence_reference)
values
  ('JLC-NODE-KINGSTON-WESTLANDS', 'Kingston Port / Westlands', 'PORT', 'Kingston', 'PLANNING', 'JIS:NEAR-PORT-LANDS'),
  ('JLC-NODE-TINSON-PEN', 'Tinson Pen Near-Port Logistics Node', 'NEAR_PORT', 'Kingston', 'PLANNING', 'JIS:NEAR-PORT-LANDS'),
  ('JLC-NODE-CAYMANAS-SEZ', 'Caymanas Special Economic Zone', 'SEZ', 'St. Catherine', 'PLANNING', 'JIS:CAYMANAS-SEZ'),
  ('JLC-NODE-JRC-MULTIMODAL', 'Jamaica Railway Multimodal Connector', 'RAIL', 'Jamaica', 'PLANNING', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE')
on conflict (node_code) do nothing;

insert into jlc.corridor_nodes (corridor_code, node_code, sequence_no, node_role, evidence_reference)
values
  ('JLC-001', 'JLC-NODE-KINGSTON-WESTLANDS', 1, 'MARITIME_GATEWAY', 'JIS:NEAR-PORT-LANDS'),
  ('JLC-001', 'JLC-NODE-TINSON-PEN', 2, 'NEAR_PORT_VALUE_ADD', 'JIS:NEAR-PORT-LANDS'),
  ('JLC-001', 'JLC-NODE-CAYMANAS-SEZ', 3, 'INLAND_SEZ_LOGISTICS', 'JIS:CAYMANAS-SEZ'),
  ('JLC-001', 'JLC-NODE-JRC-MULTIMODAL', 4, 'RAIL_MULTIMODAL_CONNECTOR', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE')
on conflict (corridor_code, node_code) do nothing;

insert into jlc.programs (program_code, corridor_code, name, program_type, lifecycle_state, description, evidence_reference)
values
  ('JLC-PROG-JRC-MULTIMODAL', 'JLC-001', 'JRC Freight Rail Activation & Multimodal Logistics Platform', 'RAIL_ACTIVATION', 'PLANNING', 'Sea-Rail-Truck/Air logistics architecture centered on Kingston Port and national freight corridors.', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'),
  ('JLC-PROG-RGL-COLDCHAIN', 'JLC-001', 'RGL Jamaica Cold-Chain Distribution Platform', 'COLD_CHAIN', 'PLANNING', 'Kingston-centered refrigerated distribution and cross-dock operating program with island-wide route coverage.', 'DRIVE:RGL-JAMAICA-COLDCHAIN')
on conflict (program_code) do nothing;

insert into jlc.corridor_organizations (corridor_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-001', oid, 'OPERATING_PLATFORM', 'PENDING_VERIFICATION', 'DRIVE:RGL-JAMAICA-COLDCHAIN'
from public.setc_organizations where legal_name = 'Robert Global Logistics LLC'
on conflict do nothing;

insert into jlc.corridor_organizations (corridor_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-001', oid, 'RAIL_COUNTERPARTY_REFERENCE', case when verification_state = 'VERIFIED' then 'VERIFIED' else 'PENDING_VERIFICATION' end, 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
from public.setc_organizations where legal_name = 'Jamaica Railway Corporation'
on conflict do nothing;

insert into jlc.corridor_organizations (corridor_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-001', oid, 'CAPITAL_STRUCTURING_REFERENCE', 'PENDING_VERIFICATION', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
from public.setc_organizations where legal_name = 'Source Energy Capital'
on conflict do nothing;

insert into jlc.program_organizations (program_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-PROG-RGL-COLDCHAIN', oid, 'OPERATOR_REFERENCE', 'PENDING_VERIFICATION', 'DRIVE:RGL-JAMAICA-COLDCHAIN'
from public.setc_organizations where legal_name = 'Robert Global Logistics LLC'
on conflict do nothing;

insert into jlc.program_organizations (program_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-PROG-JRC-MULTIMODAL', oid, 'OPERATOR_REFERENCE', 'PENDING_VERIFICATION', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
from public.setc_organizations where legal_name = 'Robert Global Logistics LLC'
on conflict do nothing;

insert into jlc.program_organizations (program_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-PROG-JRC-MULTIMODAL', oid, 'RAIL_COUNTERPARTY_REFERENCE', case when verification_state = 'VERIFIED' then 'VERIFIED' else 'PENDING_VERIFICATION' end, 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
from public.setc_organizations where legal_name = 'Jamaica Railway Corporation'
on conflict do nothing;

insert into jlc.program_organizations (program_code, organization_oid, relationship_role, verification_state, evidence_reference)
select 'JLC-PROG-JRC-MULTIMODAL', oid, 'CAPITAL_STRUCTURING_REFERENCE', 'PENDING_VERIFICATION', 'DRIVE:JRC-FREIGHT-RAIL-PACKAGE'
from public.setc_organizations where legal_name = 'Source Energy Capital'
on conflict do nothing;

insert into jlc.evidence_links (evidence_code, subject_type, subject_reference, title, source_system, source_uri, evidence_class, verification_state)
values
  ('JLC-EV-001', 'PROGRAM', 'JLC-PROG-JRC-MULTIMODAL', 'Jamaica Railway Corporation Freight Rail Activation & Multimodal Logistics Platform', 'GOOGLE_DRIVE', 'https://docs.google.com/document/d/1beMuo9orAyPSZksmdNmMUFowHOGTXtbjLGr_iAMOYH0/edit', 'INTERNAL_DOCUMENT', 'EVIDENCE_SUPPORTED'),
  ('JLC-EV-002', 'PROGRAM', 'JLC-PROG-RGL-COLDCHAIN', 'RGL Jamaica Refrigerated Logistics Contract — Executive Opportunity Structure', 'GOOGLE_DRIVE', 'https://docs.google.com/document/d/18f3fX8BCdHGqwsJBkTlxjUsao1K9J85Vz_2S2kTJA8k/edit', 'INTERNAL_DOCUMENT', 'EVIDENCE_SUPPORTED'),
  ('JLC-EV-003', 'CORRIDOR', 'JLC-001', 'Government Developing Near-Port Lands to Unlock Logistics Investments', 'JAMAICA_INFORMATION_SERVICE', 'https://jis.gov.jm/govt-developing-near-port-lands-to-unlock-logistics-investments/', 'OFFICIAL_SOURCE', 'VERIFIED_REFERENCE')
on conflict (evidence_code) do nothing;
