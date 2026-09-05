create table if not exists ecology.ssr_reference_addresses (
  id uuid primary key default gen_random_uuid(),
  context_name text not null unique,
  canonical_address text,
  surface_anchor text,
  z_index integer check(z_index is null or z_index between -1000 and 1000),
  altitude_m integer,
  governance_domain text,
  evidence_class text not null,
  source_reference text not null,
  roster_mapping_status text not null default 'unmapped' check(roster_mapping_status in ('unmapped','candidate','verified_reference','promoted','rejected')),
  authority_boundary text not null default 'Reference evidence only. Does not establish membership in the authoritative 729 AnchorTile roster without explicit row concordance.',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table ecology.ssr_reference_addresses enable row level security;
drop policy if exists ssr_reference_addresses_service_role_all on ecology.ssr_reference_addresses;
create policy ssr_reference_addresses_service_role_all on ecology.ssr_reference_addresses for all to service_role using (true) with check (true);

insert into ecology.ssr_reference_addresses(context_name,canonical_address,surface_anchor,z_index,altitude_m,governance_domain,evidence_class,source_reference)
values
('Bernard Lodge Solar Panel','///solar.lodge.bernard@Z+0001','///solar.lodge.bernard',1,3,'Energy — agrovoltaic surface registration','Operational context address','Google Drive: 729-Cube Autonomy Scorecard / Verified SSR Addresses / SSR Technical Whitepaper Scroll #411'),
('SkyJetz Cruise Altitude','///kingston.miami.route@Z+0350','///kingston.miami.route',350,1050,'Aviation — Jamaica-Miami corridor cube','Operational context address','Google Drive: 729-Cube Autonomy Scorecard / Verified SSR Addresses / SSR Technical Whitepaper Scroll #411'),
('Community Trust Ring-Fence','///bernard.lodge.east@Z+0000','///bernard.lodge.east',0,0,'Community equity — ring-fence boundary marker','Operational context address','Google Drive: 729-Cube Autonomy Scorecard / Verified SSR Addresses / SSR Technical Whitepaper Scroll #411'),
('Black River Hospital Boundary','///black.river.hospital@Z+0002','///black.river.hospital',2,6,'Healthcare corridor — facility boundary','Operational context address','Google Drive: 729-Cube Autonomy Scorecard / Verified SSR Addresses / SSR Technical Whitepaper Scroll #411'),
('Carbon Attribution Cube','///solar.carbon.grid@Z+0050','///solar.carbon.grid',50,150,'Environmental — carbon credit spatial attribution','Operational context address','Google Drive: 729-Cube Autonomy Scorecard / Verified SSR Addresses / SSR Technical Whitepaper Scroll #411')
on conflict(context_name) do update set canonical_address=excluded.canonical_address,surface_anchor=excluded.surface_anchor,z_index=excluded.z_index,altitude_m=excluded.altitude_m,governance_domain=excluded.governance_domain,evidence_class=excluded.evidence_class,source_reference=excluded.source_reference,updated_at=now();

create table if not exists ecology.ssr_concordance_status (
  concordance_code text primary key,
  expected_anchor_count integer not null default 729 check(expected_anchor_count=729),
  authoritative_roster_rows integer not null default 0,
  mapped_anchor_rows integer not null default 0,
  unresolved_anchor_rows integer generated always as (expected_anchor_count-mapped_anchor_rows) stored,
  current_state text not null check(current_state in ('blocked_external_dependency','acquisition_in_progress','validation_in_progress','partial_mapping','ready_for_promotion','complete')),
  blocker text not null,
  source_owner_action text not null,
  last_verified_at timestamptz not null default now(),
  provenance jsonb not null default '{}'::jsonb
);
alter table ecology.ssr_concordance_status enable row level security;
drop policy if exists ssr_concordance_status_service_role_all on ecology.ssr_concordance_status;
create policy ssr_concordance_status_service_role_all on ecology.ssr_concordance_status for all to service_role using (true) with check (true);

insert into ecology.ssr_concordance_status(concordance_code,authoritative_roster_rows,mapped_anchor_rows,current_state,blocker,source_owner_action,provenance)
values('SSR-729-W3W-CONCORDANCE',0,0,'blocked_external_dependency','Authoritative 729-row AnchorTile roster/export has not been located in connected Drive, GitHub, Dropbox, current Supabase, or connected communications. Existing operational example addresses lack stable 729-row identity mapping.','Recover the unchanged March-April 2026 SSR AnchorTile system-of-record export or equivalent authenticated registry/API/object-store artifact with provenance, checksum, activation timestamps, W3W addresses, and WGS84 coordinates.',jsonb_build_object('github_issue',2,'drive_scorecard','13jP8xJBR5EGhrNCOdom4_jc3ln56cHOfVsZfjHJ7Xhs','w3w_resolver_edge_function','ssr-what3words-resolver','lattice_assets',1458729))
on conflict(concordance_code) do update set authoritative_roster_rows=excluded.authoritative_roster_rows,mapped_anchor_rows=excluded.mapped_anchor_rows,current_state=excluded.current_state,blocker=excluded.blocker,source_owner_action=excluded.source_owner_action,last_verified_at=now(),provenance=excluded.provenance;

create or replace view ecology.ssr_control_plane_status as
select c.concordance_code,c.expected_anchor_count,c.authoritative_roster_rows,c.mapped_anchor_rows,c.unresolved_anchor_rows,c.current_state,c.blocker,c.source_owner_action,c.last_verified_at,
       cap.vertical_layers,cap.governed_spatial_assets,cap.currently_addressable_assets,
       (select count(*) from ecology.ssr_reference_addresses) as operational_reference_addresses,
       (select count(*) from public.anchor_tiles) as authoritative_anchor_tiles,
       (select count(*) from public.spatial_cubes) as materialized_spatial_cubes
from ecology.ssr_concordance_status c cross join ecology.ssr_architecture_capacity cap;

