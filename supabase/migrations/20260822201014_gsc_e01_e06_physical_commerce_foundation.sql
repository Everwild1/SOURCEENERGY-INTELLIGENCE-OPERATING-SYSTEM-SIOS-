create schema if not exists gsc;

revoke all on schema gsc from public;
revoke all on schema gsc from anon, authenticated;
grant usage on schema gsc to service_role;

create table if not exists gsc.commodities (
  id uuid primary key default gen_random_uuid(),
  commodity_code text not null unique,
  category text not null check (category in ('energy_fuel','critical_material','industrial_material','agriculture','water_infrastructure')),
  name text not null,
  description text,
  specification jsonb not null default '{}'::jsonb,
  wim_product_service_id uuid references wim.products_services(id) on delete set null,
  status text not null default 'design' check (status in ('design','active','suspended','retired')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gsc.supply_nodes (
  id uuid primary key default gen_random_uuid(),
  node_code text not null unique,
  display_name text not null,
  node_type text not null check (node_type in ('plant','terminal','port','warehouse','distribution_center','materials_node','logistics_hub','supplier_site')),
  verification_status text not null default 'candidate' check (verification_status in ('candidate','verified','active','suspended','retired')),
  wim_organization_id uuid references wim.organizations(id) on delete set null,
  rgl_organization_id uuid references rgl.organizations(id) on delete set null,
  rgl_facility_id uuid references rgl.facilities(id) on delete set null,
  rgl_logistics_hub_id uuid references rgl.logistics_hubs(id) on delete set null,
  ssr_registry_id uuid references public.ssr_spatial_registry(id) on delete set null,
  jurisdiction_code text,
  region_focus text[] not null default '{}'::text[],
  metadata jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gsc.corridor_portfolio (
  id uuid primary key default gen_random_uuid(),
  portfolio_code text not null unique,
  name text not null,
  rgl_corridor_id uuid references rgl.corridors(id) on delete set null,
  wim_trade_corridor_id uuid references wim.trade_corridors(id) on delete set null,
  priority_scope text,
  diaspora_connector boolean not null default false,
  status text not null default 'design' check (status in ('design','active','suspended','retired')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gsc.distribution_programs (
  id uuid primary key default gen_random_uuid(),
  program_code text not null unique,
  name text not null,
  program_type text not null check (program_type in ('energy_distribution','materials_distribution','agriculture_distribution','infrastructure_distribution')),
  status text not null default 'design' check (status in ('design','pilot','active','suspended','retired')),
  origin_node_id uuid references gsc.supply_nodes(id) on delete set null,
  destination_node_id uuid references gsc.supply_nodes(id) on delete set null,
  corridor_portfolio_id uuid references gsc.corridor_portfolio(id) on delete set null,
  operator_wim_organization_id uuid references wim.organizations(id) on delete set null,
  operator_rgl_organization_id uuid references rgl.organizations(id) on delete set null,
  scope jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gsc.distribution_program_commodities (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references gsc.distribution_programs(id) on delete cascade,
  commodity_id uuid not null references gsc.commodities(id) on delete restrict,
  role text not null default 'primary' check (role in ('primary','secondary','contingency')),
  target_quantity numeric check (target_quantity is null or target_quantity >= 0),
  unit text,
  specification jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(program_id, commodity_id, role)
);

create index if not exists idx_gsc_commodities_wim_product_service on gsc.commodities(wim_product_service_id);
create index if not exists idx_gsc_supply_nodes_wim_org on gsc.supply_nodes(wim_organization_id);
create index if not exists idx_gsc_supply_nodes_rgl_org on gsc.supply_nodes(rgl_organization_id);
create index if not exists idx_gsc_supply_nodes_rgl_facility on gsc.supply_nodes(rgl_facility_id);
create index if not exists idx_gsc_supply_nodes_rgl_hub on gsc.supply_nodes(rgl_logistics_hub_id);
create index if not exists idx_gsc_supply_nodes_ssr on gsc.supply_nodes(ssr_registry_id);
create index if not exists idx_gsc_corridor_portfolio_rgl on gsc.corridor_portfolio(rgl_corridor_id);
create index if not exists idx_gsc_corridor_portfolio_wim on gsc.corridor_portfolio(wim_trade_corridor_id);
create index if not exists idx_gsc_distribution_origin on gsc.distribution_programs(origin_node_id);
create index if not exists idx_gsc_distribution_destination on gsc.distribution_programs(destination_node_id);
create index if not exists idx_gsc_distribution_corridor on gsc.distribution_programs(corridor_portfolio_id);
create index if not exists idx_gsc_distribution_wim_operator on gsc.distribution_programs(operator_wim_organization_id);
create index if not exists idx_gsc_distribution_rgl_operator on gsc.distribution_programs(operator_rgl_organization_id);
create index if not exists idx_gsc_program_commodities_commodity on gsc.distribution_program_commodities(commodity_id);

alter table gsc.commodities enable row level security;
alter table gsc.supply_nodes enable row level security;
alter table gsc.corridor_portfolio enable row level security;
alter table gsc.distribution_programs enable row level security;
alter table gsc.distribution_program_commodities enable row level security;

revoke all on all tables in schema gsc from anon, authenticated;
grant select, insert, update, delete on all tables in schema gsc to service_role;

alter default privileges for role postgres in schema gsc revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema gsc grant select, insert, update, delete on tables to service_role;
alter default privileges for role postgres in schema gsc revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema gsc grant usage, select on sequences to service_role;

insert into gsc.commodities (commodity_code, category, name, description, provenance)
values
  ('DIESEL-ULSD-10PPM','energy_fuel','Diesel / ULSD 10 PPM','Ultra-low-sulfur diesel distribution commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('JET-A1','energy_fuel','Jet A-1','Aviation turbine fuel commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('AGO','energy_fuel','Automotive Gas Oil (AGO)','Automotive gas oil commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('GASOLINE','energy_fuel','Gasoline','Motor gasoline commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('LPG','energy_fuel','Liquefied Petroleum Gas','LPG commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('LNG','energy_fuel','Liquefied Natural Gas','LNG commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('CRUDE-OIL','energy_fuel','Crude Oil','Crude petroleum commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('BASE-OILS','energy_fuel','Base Oils','Base oil commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('BITUMEN','energy_fuel','Bitumen','Bitumen and asphalt feedstock commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('LITHIUM-HYDROXIDE-BATTERY','critical_material','Battery-Grade Lithium Hydroxide','Battery-grade lithium hydroxide commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('BATTERY-MATERIALS','critical_material','Battery Materials','Governed battery-material input class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('GRAPHITE','critical_material','Graphite','Graphite commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('GRAPHENE','critical_material','Graphene','Graphene material class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('INDUSTRIAL-MATERIALS','industrial_material','Industrial Materials','Governed industrial materials commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('UREA','agriculture','Urea','Urea fertilizer commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('FERTILIZER','agriculture','Fertilizer','Fertilizer commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('AGRICULTURAL-COMMODITIES','agriculture','Agricultural Commodities','Governed agricultural commodity class.',jsonb_build_object('source','GSC-01','governance_status','design')),
  ('WATER-INFRASTRUCTURE-COMPONENTS','water_infrastructure','Water & Infrastructure Components','Water-system and infrastructure component class.',jsonb_build_object('source','GSC-01','governance_status','design'))
on conflict (commodity_code) do nothing;

insert into gsc.supply_nodes (node_code, display_name, node_type, verification_status, region_focus, metadata, provenance)
values (
  'GSC-PERRYVILLE-MATERIALS',
  'Perryville Materials Node',
  'materials_node',
  'candidate',
  array['North America']::text[],
  jsonb_build_object('activation_blocked',true,'required_action','authoritative organization/facility identity reconciliation'),
  jsonb_build_object('source','GSC-06','identity_reconciliation','required','asserted_operational_status',false)
)
on conflict (node_code) do nothing;

insert into gsc.corridor_portfolio (portfolio_code, name, priority_scope, diaspora_connector, status, provenance)
values (
  'GSC-NACA-AFRICA',
  'North America–Caribbean Basin–Africa Priority Network',
  'Global coverage with dedicated North America, Caribbean Basin and Africa operating focus',
  true,
  'design',
  jsonb_build_object('source','GSC-03','record_type','portfolio_aggregate','physical_corridor_asserted',false)
)
on conflict (portfolio_code) do nothing;

insert into gsc.distribution_programs (program_code, name, program_type, status, corridor_portfolio_id, scope, provenance)
select
  'GSC-DIESEL-GLOBAL-001',
  'Diesel and ULSD Distribution Program',
  'energy_distribution',
  'design',
  cp.id,
  jsonb_build_object('regions',jsonb_build_array('North America','Caribbean Basin','Africa'),'market_scope','global','commodity_focus','diesel/ULSD'),
  jsonb_build_object('source','GSC-05','commercial_activation','requires qualified counterparties and compliance approval')
from gsc.corridor_portfolio cp
where cp.portfolio_code = 'GSC-NACA-AFRICA'
on conflict (program_code) do nothing;

insert into gsc.distribution_program_commodities (program_id, commodity_id, role, specification)
select p.id, c.id, x.role, x.specification
from gsc.distribution_programs p
join (values
  ('DIESEL-ULSD-10PPM'::text,'primary'::text,jsonb_build_object('sulfur_max_ppm',10)),
  ('AGO'::text,'secondary'::text,'{}'::jsonb)
) as x(commodity_code, role, specification) on true
join gsc.commodities c on c.commodity_code = x.commodity_code
where p.program_code = 'GSC-DIESEL-GLOBAL-001'
on conflict (program_id, commodity_id, role) do nothing;
