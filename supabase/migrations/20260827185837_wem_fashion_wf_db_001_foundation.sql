create schema if not exists fashion;

comment on schema fashion is 'WEM Fashion Industry 4.0 bounded domain. Fashion-specific product and lifecycle semantics only; identity, generic creator/work rights, market execution, logistics, capitalization and settlement remain authoritative in their existing SIOS domains.';

grant usage on schema fashion to service_role;
revoke all on schema fashion from anon, authenticated;

create table fashion.brands (
  id uuid primary key default gen_random_uuid(),
  brand_code text not null unique,
  display_name text not null,
  owner_organization_oid text not null references public.setc_organizations(oid),
  wim_organization_id uuid references wim.organizations(id),
  status text not null default 'draft' check (status in ('draft','active','suspended','archived')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table fashion.brands is 'Fashion brand projection bound to authoritative SETC organization identity; does not create legal ownership, trademark rights, or market authorization.';

create table fashion.designs (
  id uuid primary key default gen_random_uuid(),
  design_code text not null unique,
  brand_id uuid not null references fashion.brands(id),
  cruds_work_id uuid not null unique references cruds.works(id),
  seae_work_id uuid unique references seae.work_registry(work_id),
  design_category text not null,
  season_label text,
  lifecycle_status text not null default 'concept' check (lifecycle_status in ('concept','development','approved','production','retired','archived')),
  technical_specification jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table fashion.designs is 'Fashion-specific projection of an authoritative CRUDS work. Rights, consent, provenance and licensing remain authoritative in CRUDS/SEAE.';

create table fashion.collections (
  id uuid primary key default gen_random_uuid(),
  collection_code text not null unique,
  brand_id uuid not null references fashion.brands(id),
  name text not null,
  season_label text,
  launch_date date,
  status text not null default 'planning' check (status in ('planning','development','launched','closed','archived')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table fashion.collection_designs (
  collection_id uuid not null references fashion.collections(id) on delete cascade,
  design_id uuid not null references fashion.designs(id) on delete cascade,
  sequence_no integer,
  primary key (collection_id, design_id)
);

create table fashion.materials (
  id uuid primary key default gen_random_uuid(),
  material_code text not null unique,
  name text not null,
  material_class text not null,
  gsc_commodity_id uuid references gsc.commodities(id),
  composition jsonb not null default '{}'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  circularity_profile jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('draft','active','restricted','retired')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table fashion.materials is 'Fashion material semantics with optional reference to authoritative GSC commodity records; certification fields are evidence metadata, not certification authority.';

create table fashion.design_materials (
  design_id uuid not null references fashion.designs(id) on delete cascade,
  material_id uuid not null references fashion.materials(id),
  usage_role text not null default 'primary',
  quantity numeric,
  unit text,
  specification jsonb not null default '{}'::jsonb,
  primary key (design_id, material_id, usage_role),
  check (quantity is null or quantity >= 0)
);

create table fashion.product_models (
  id uuid primary key default gen_random_uuid(),
  product_code text not null unique,
  design_id uuid not null references fashion.designs(id),
  brand_id uuid not null references fashion.brands(id),
  wim_product_service_id uuid unique references wim.products_services(id),
  product_name text not null,
  product_type text not null,
  status text not null default 'development' check (status in ('development','active','paused','retired','archived')),
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table fashion.product_models is 'Fashion product master projection. WIM remains authoritative for market offering, pricing, opportunity and transaction execution.';

create table fashion.skus (
  id uuid primary key default gen_random_uuid(),
  product_model_id uuid not null references fashion.product_models(id),
  sku_code text not null unique,
  size_code text,
  color_code text,
  variant_attributes jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('development','active','paused','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table fashion.production_orders (
  id uuid primary key default gen_random_uuid(),
  production_order_code text not null unique,
  brand_id uuid not null references fashion.brands(id),
  seae_production_id uuid references seae.productions(id),
  gsc_supply_node_id uuid references gsc.supply_nodes(id),
  rgl_order_id uuid references rgl.orders(id),
  status text not null default 'planned' check (status in ('planned','approved','in_production','completed','cancelled','closed')),
  planned_start date,
  planned_end date,
  evidence_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (planned_end is null or planned_start is null or planned_end >= planned_start)
);
comment on table fashion.production_orders is 'Fashion production planning record. It does not replace SEAE production authority, GSC supply-node authority, RGL logistics orders, or contractual authorization.';

create table fashion.production_order_items (
  id uuid primary key default gen_random_uuid(),
  production_order_id uuid not null references fashion.production_orders(id) on delete cascade,
  sku_id uuid not null references fashion.skus(id),
  planned_quantity integer not null check (planned_quantity > 0),
  completed_quantity integer not null default 0 check (completed_quantity >= 0),
  created_at timestamptz not null default now(),
  unique (production_order_id, sku_id),
  check (completed_quantity <= planned_quantity)
);

create table fashion.production_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique,
  production_order_id uuid not null references fashion.production_orders(id),
  sku_id uuid not null references fashion.skus(id),
  quantity integer not null check (quantity > 0),
  produced_at timestamptz,
  origin_supply_node_id uuid references gsc.supply_nodes(id),
  rgl_shipment_id uuid references rgl.shipments(id),
  status text not null default 'planned' check (status in ('planned','in_production','quality_hold','released','shipped','closed')),
  quality_evidence_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table fashion.product_instances (
  id uuid primary key default gen_random_uuid(),
  instance_code text not null unique,
  sku_id uuid not null references fashion.skus(id),
  production_batch_id uuid references fashion.production_batches(id),
  serial_number text unique,
  digital_passport_reference text,
  current_lifecycle_state text not null default 'manufactured' check (current_lifecycle_state in ('manufactured','in_inventory','sold','in_use','repair','resale','returned','recycled','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table fashion.product_instances is 'Serialized fashion product identity and lifecycle projection; digital passport reference is a pointer and not independent proof of ownership or authenticity.';

create table fashion.circular_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  product_instance_id uuid not null references fashion.product_instances(id),
  event_type text not null check (event_type in ('manufactured','inventory','sale','transfer','use','repair','return','resale','recycle','retire')),
  occurred_at timestamptz not null,
  actor_organization_oid text references public.setc_organizations(oid),
  evidence_reference text,
  location_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
comment on table fashion.circular_lifecycle_events is 'Append-oriented lifecycle evidence. Events do not confer title, payment finality, certification, or regulatory approval.';

create table fashion.reflex_evidence_links (
  id uuid primary key default gen_random_uuid(),
  design_id uuid references fashion.designs(id),
  product_instance_id uuid references fashion.product_instances(id),
  seae_rights_interest_id uuid references seae.rights_interests(id),
  seae_license_id uuid references seae.licenses(id),
  seae_consent_id uuid references seae.consent_records(id),
  evidence_reference text not null,
  evidence_type text not null,
  verification_state text not null default 'unverified' check (verification_state in ('unverified','submitted','verified','rejected','superseded')),
  created_at timestamptz not null default now(),
  check (design_id is not null or product_instance_id is not null)
);
comment on table fashion.reflex_evidence_links is 'Fashion RefleX evidence/rights adapter. References authoritative SEAE rights, licenses and consent; does not create or override rights.';

create index fashion_designs_brand_idx on fashion.designs(brand_id);
create index fashion_collections_brand_idx on fashion.collections(brand_id);
create index fashion_design_materials_material_idx on fashion.design_materials(material_id);
create index fashion_product_models_design_idx on fashion.product_models(design_id);
create index fashion_product_models_brand_idx on fashion.product_models(brand_id);
create index fashion_skus_product_idx on fashion.skus(product_model_id);
create index fashion_production_orders_brand_idx on fashion.production_orders(brand_id);
create index fashion_production_order_items_sku_idx on fashion.production_order_items(sku_id);
create index fashion_production_batches_order_idx on fashion.production_batches(production_order_id);
create index fashion_production_batches_sku_idx on fashion.production_batches(sku_id);
create index fashion_product_instances_sku_idx on fashion.product_instances(sku_id);
create index fashion_product_instances_batch_idx on fashion.product_instances(production_batch_id);
create index fashion_lifecycle_instance_time_idx on fashion.circular_lifecycle_events(product_instance_id, occurred_at);
create index fashion_reflex_design_idx on fashion.reflex_evidence_links(design_id);
create index fashion_reflex_instance_idx on fashion.reflex_evidence_links(product_instance_id);

alter table fashion.brands enable row level security;
alter table fashion.designs enable row level security;
alter table fashion.collections enable row level security;
alter table fashion.collection_designs enable row level security;
alter table fashion.materials enable row level security;
alter table fashion.design_materials enable row level security;
alter table fashion.product_models enable row level security;
alter table fashion.skus enable row level security;
alter table fashion.production_orders enable row level security;
alter table fashion.production_order_items enable row level security;
alter table fashion.production_batches enable row level security;
alter table fashion.product_instances enable row level security;
alter table fashion.circular_lifecycle_events enable row level security;
alter table fashion.reflex_evidence_links enable row level security;

grant select, insert, update, delete on all tables in schema fashion to service_role;

create policy fashion_brands_service_role_all on fashion.brands for all to service_role using (true) with check (true);
create policy fashion_designs_service_role_all on fashion.designs for all to service_role using (true) with check (true);
create policy fashion_collections_service_role_all on fashion.collections for all to service_role using (true) with check (true);
create policy fashion_collection_designs_service_role_all on fashion.collection_designs for all to service_role using (true) with check (true);
create policy fashion_materials_service_role_all on fashion.materials for all to service_role using (true) with check (true);
create policy fashion_design_materials_service_role_all on fashion.design_materials for all to service_role using (true) with check (true);
create policy fashion_product_models_service_role_all on fashion.product_models for all to service_role using (true) with check (true);
create policy fashion_skus_service_role_all on fashion.skus for all to service_role using (true) with check (true);
create policy fashion_production_orders_service_role_all on fashion.production_orders for all to service_role using (true) with check (true);
create policy fashion_production_order_items_service_role_all on fashion.production_order_items for all to service_role using (true) with check (true);
create policy fashion_production_batches_service_role_all on fashion.production_batches for all to service_role using (true) with check (true);
create policy fashion_product_instances_service_role_all on fashion.product_instances for all to service_role using (true) with check (true);
create policy fashion_circular_events_service_role_all on fashion.circular_lifecycle_events for all to service_role using (true) with check (true);
create policy fashion_reflex_links_service_role_all on fashion.reflex_evidence_links for all to service_role using (true) with check (true);

revoke all on all tables in schema fashion from anon, authenticated;

alter default privileges in schema fashion grant select, insert, update, delete on tables to service_role;
alter default privileges in schema fashion revoke all on tables from anon, authenticated;
