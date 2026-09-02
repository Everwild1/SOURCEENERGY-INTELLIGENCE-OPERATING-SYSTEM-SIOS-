create table seae.cultural_assets (
  id uuid primary key default gen_random_uuid(),
  asset_reference text not null unique,
  title text not null check (length(btrim(title)) > 0),
  asset_type text not null,
  creator_id uuid references cruds.creators(id),
  owner_organization_oid text references public.setc_organizations(oid),
  steward_organization_oid text references public.setc_organizations(oid),
  cultural_authority_id uuid references seae.cultural_authorities(id),
  related_work_id uuid references cruds.works(id),
  provenance_reference text,
  cultural_context text,
  location_reference text,
  condition_status text,
  access_status text not null default 'controlled' check (access_status in ('public','controlled','restricted','sacred','closed','unknown')),
  permitted_uses text[] not null default '{}',
  restrictions text[] not null default '{}',
  rights_status text not null default 'unverified' check (rights_status in ('unverified','asserted','partially_verified','verified','disputed','restricted')),
  lifecycle_status text not null default 'active' check (lifecycle_status in ('draft','active','restricted','disputed','repatriation_review','archived','withdrawn')),
  review_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table seae.cultural_assets is 'Governance registry for cultural and heritage assets. Registration does not create ownership or extinguish community, moral, customary, statutory, or third-party rights.';

create table seae.heritage_stewardship_plans (
  id uuid primary key default gen_random_uuid(),
  cultural_asset_id uuid not null references seae.cultural_assets(id) on delete cascade,
  significance_statement text,
  custody_terms text,
  conservation_plan text,
  access_plan text,
  security_plan text,
  disaster_recovery_plan text,
  succession_plan text,
  funding_reference text,
  responsible_organization_oid text references public.setc_organizations(oid),
  effective_from date,
  review_date date,
  status text not null default 'draft' check (status in ('draft','active','under_review','superseded','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table seae.cultural_claims (
  id uuid primary key default gen_random_uuid(),
  cultural_asset_id uuid references seae.cultural_assets(id) on delete cascade,
  work_id uuid references cruds.works(id) on delete cascade,
  claimant_creator_id uuid references cruds.creators(id),
  claimant_organization_oid text references public.setc_organizations(oid),
  claimant_authority_id uuid references seae.cultural_authorities(id),
  claim_type text not null check (claim_type in ('ownership','authorship','attribution','custody','repatriation','restitution','misappropriation','consent','access','compensation','other')),
  claim_summary text not null,
  evidence_reference text,
  status text not null default 'submitted' check (status in ('submitted','under_review','evidence_requested','mediating','resolved','rejected','withdrawn','appealed')),
  remedy_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (cultural_asset_id is not null or work_id is not null),
  check (claimant_creator_id is not null or claimant_organization_oid is not null or claimant_authority_id is not null)
);

create table seae.events (
  id uuid primary key default gen_random_uuid(),
  event_reference text not null unique,
  title text not null check (length(btrim(title)) > 0),
  event_type text not null,
  organizer_organization_oid text references public.setc_organizations(oid),
  cultural_authority_id uuid references seae.cultural_authorities(id),
  venue_reference text,
  country_code text,
  region_code text,
  starts_at timestamptz,
  ends_at timestamptz,
  ticketing_model text,
  sponsorship_status text,
  rights_clearance_status text not null default 'pending' check (rights_clearance_status in ('pending','partial','cleared','restricted','blocked','disputed')),
  safeguarding_status text not null default 'pending' check (safeguarding_status in ('pending','reviewed','approved','restricted','blocked')),
  status text not null default 'planning' check (status in ('planning','approved','announced','on_sale','active','completed','cancelled','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at >= starts_at)
);

create table seae.event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references seae.events(id) on delete cascade,
  creator_id uuid references cruds.creators(id),
  organization_oid text references public.setc_organizations(oid),
  participant_role text not null,
  contract_reference text,
  compensation_terms text,
  rights_terms text,
  created_at timestamptz not null default now(),
  check (creator_id is not null or organization_oid is not null)
);

create table seae.distribution_rights (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id) on delete cascade,
  license_id uuid references seae.licenses(id),
  distributor_organization_oid text references public.setc_organizations(oid),
  distribution_channel text not null,
  territory text,
  language_code text,
  window_start timestamptz,
  window_end timestamptz,
  exclusivity text not null default 'nonexclusive' check (exclusivity in ('exclusive','nonexclusive','sole','restricted')),
  monetization_model text,
  revenue_share_terms text,
  evidence_reference text,
  status text not null default 'draft' check (status in ('draft','pending','active','suspended','expired','terminated','disputed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (window_end is null or window_start is null or window_end >= window_start)
);

create table seae.wim_cluster_links (
  id bigint generated always as identity primary key,
  cluster_id bigint not null references wim.economic_clusters(id),
  seae_domain text not null,
  link_role text not null default 'market_classification',
  evidence_reference text,
  verification_status text not null default 'asserted' check (verification_status in ('asserted','pending_verification','verified','rejected','retired')),
  created_at timestamptz not null default now(),
  unique (cluster_id, seae_domain, link_role)
);

create table seae.wim_organization_links (
  organization_oid text not null references public.setc_organizations(oid) on delete cascade,
  wim_organization_id uuid not null references wim.organizations(id) on delete cascade,
  link_role text not null default 'commercial_identity',
  verification_status text not null default 'asserted' check (verification_status in ('asserted','pending_verification','verified','rejected','retired')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  primary key (organization_oid, wim_organization_id, link_role)
);

create table seae.wim_offering_links (
  id bigint generated always as identity primary key,
  wim_product_service_id uuid not null references wim.products_services(id) on delete cascade,
  work_id uuid references cruds.works(id) on delete cascade,
  cultural_asset_id uuid references seae.cultural_assets(id) on delete cascade,
  event_id uuid references seae.events(id) on delete cascade,
  production_id uuid references seae.productions(id) on delete cascade,
  offering_role text not null,
  created_at timestamptz not null default now(),
  check (num_nonnulls(work_id,cultural_asset_id,event_id,production_id)=1)
);

create table seae.wim_opportunity_links (
  id bigint generated always as identity primary key,
  wim_opportunity_id uuid not null references wim.opportunities(id) on delete cascade,
  work_id uuid references cruds.works(id) on delete cascade,
  cultural_asset_id uuid references seae.cultural_assets(id) on delete cascade,
  event_id uuid references seae.events(id) on delete cascade,
  production_id uuid references seae.productions(id) on delete cascade,
  opportunity_role text not null,
  created_at timestamptz not null default now(),
  check (num_nonnulls(work_id,cultural_asset_id,event_id,production_id)=1)
);

insert into seae.wim_cluster_links (cluster_id,seae_domain,link_role,evidence_reference,verification_status)
select id,'arts_entertainment','market_classification','WIM-L10 verified taxonomy','verified'
from wim.economic_clusters
where canonical_code='WIM-L10' and verification_status='verified'
on conflict (cluster_id,seae_domain,link_role) do nothing;

create index seae_cultural_assets_work_idx on seae.cultural_assets(related_work_id);
create index seae_cultural_assets_authority_idx on seae.cultural_assets(cultural_authority_id);
create index seae_events_org_idx on seae.events(organizer_organization_oid);
create index seae_distribution_rights_work_idx on seae.distribution_rights(work_id);
create index seae_wim_offering_links_product_idx on seae.wim_offering_links(wim_product_service_id);
create index seae_wim_opportunity_links_opportunity_idx on seae.wim_opportunity_links(wim_opportunity_id);

alter table seae.cultural_assets enable row level security;
alter table seae.heritage_stewardship_plans enable row level security;
alter table seae.cultural_claims enable row level security;
alter table seae.events enable row level security;
alter table seae.event_participants enable row level security;
alter table seae.distribution_rights enable row level security;
alter table seae.wim_cluster_links enable row level security;
alter table seae.wim_organization_links enable row level security;
alter table seae.wim_offering_links enable row level security;
alter table seae.wim_opportunity_links enable row level security;

grant all privileges on all tables in schema seae to service_role;
grant usage, select on all sequences in schema seae to service_role;

create policy seae_cultural_assets_service_role_all on seae.cultural_assets for all to service_role using (true) with check (true);
create policy seae_heritage_stewardship_plans_service_role_all on seae.heritage_stewardship_plans for all to service_role using (true) with check (true);
create policy seae_cultural_claims_service_role_all on seae.cultural_claims for all to service_role using (true) with check (true);
create policy seae_events_service_role_all on seae.events for all to service_role using (true) with check (true);
create policy seae_event_participants_service_role_all on seae.event_participants for all to service_role using (true) with check (true);
create policy seae_distribution_rights_service_role_all on seae.distribution_rights for all to service_role using (true) with check (true);
create policy seae_wim_cluster_links_service_role_all on seae.wim_cluster_links for all to service_role using (true) with check (true);
create policy seae_wim_organization_links_service_role_all on seae.wim_organization_links for all to service_role using (true) with check (true);
create policy seae_wim_offering_links_service_role_all on seae.wim_offering_links for all to service_role using (true) with check (true);
create policy seae_wim_opportunity_links_service_role_all on seae.wim_opportunity_links for all to service_role using (true) with check (true);
