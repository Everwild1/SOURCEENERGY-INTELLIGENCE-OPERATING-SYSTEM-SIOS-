alter table public.set_entity_governance_relationships enable row level security;
alter table public.set_genesis_cube_contributions enable row level security;
alter table public.set_genesis_cube_lab_memberships enable row level security;
alter table public.set_genesis_cubes enable row level security;
alter table public.set_sourcecube_lab_technology_links enable row level security;
alter table public.set_sourcecube_labs enable row level security;

create policy set_entity_governance_relationships_service_role_all
on public.set_entity_governance_relationships
for all
to service_role
using (true)
with check (true);

create policy set_genesis_cube_contributions_service_role_all
on public.set_genesis_cube_contributions
for all
to service_role
using (true)
with check (true);

create policy set_genesis_cube_lab_memberships_service_role_all
on public.set_genesis_cube_lab_memberships
for all
to service_role
using (true)
with check (true);

create policy set_genesis_cubes_service_role_all
on public.set_genesis_cubes
for all
to service_role
using (true)
with check (true);

create policy set_sourcecube_lab_technology_links_service_role_all
on public.set_sourcecube_lab_technology_links
for all
to service_role
using (true)
with check (true);

create policy set_sourcecube_labs_service_role_all
on public.set_sourcecube_labs
for all
to service_role
using (true)
with check (true);
