create table if not exists public.treasury_resource_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint treasury_resource_categories_code_chk check (code ~ '^[a-z0-9_]+$')
);

create table if not exists public.treasury_resources (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.treasury_resource_categories(id) on delete restrict,
  resource_code text not null unique,
  title text not null,
  description text,
  resource_type text not null default 'reference_guide',
  source_uri text,
  jurisdiction text,
  lifecycle_status text not null default 'active',
  authoritative_reference boolean not null default false,
  executable_authority boolean not null default false,
  settlement_authority boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint treasury_resources_code_chk check (resource_code ~ '^[A-Z0-9_-]+$'),
  constraint treasury_resources_type_chk check (resource_type in ('reference_guide','policy_reference','market_reference','regulatory_reference','operating_manual','data_reference','research_reference','other')),
  constraint treasury_resources_lifecycle_chk check (lifecycle_status in ('draft','active','deprecated','archived')),
  constraint treasury_resources_no_implicit_execution_chk check (not (resource_type in ('reference_guide','policy_reference','market_reference','regulatory_reference','research_reference') and executable_authority)),
  constraint treasury_resources_no_implicit_settlement_chk check (not (resource_type in ('reference_guide','policy_reference','market_reference','regulatory_reference','research_reference') and settlement_authority))
);

create table if not exists public.treasury_resource_operation_mappings (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.treasury_resources(id) on delete cascade,
  sourcecube_code text not null,
  operation_code text not null,
  operation_name text not null,
  relationship_type text not null default 'reference_only',
  execution_permitted boolean not null default false,
  settlement_permitted boolean not null default false,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint treasury_resource_operation_sourcecube_chk check (sourcecube_code in ('SC-03','SC-09','SC-11')),
  constraint treasury_resource_operation_relationship_chk check (relationship_type in ('reference_only','decision_support','control_reference','evidence_reference')),
  constraint treasury_resource_operation_no_execution_chk check (execution_permitted = false),
  constraint treasury_resource_operation_no_settlement_chk check (settlement_permitted = false),
  unique (resource_id, sourcecube_code, operation_code)
);

create index if not exists idx_treasury_resources_category_id on public.treasury_resources(category_id);
create index if not exists idx_treasury_resources_status on public.treasury_resources(lifecycle_status);
create index if not exists idx_treasury_resource_operation_sourcecube on public.treasury_resource_operation_mappings(sourcecube_code);
create index if not exists idx_treasury_resource_operation_resource on public.treasury_resource_operation_mappings(resource_id);

alter table public.treasury_resource_categories enable row level security;
alter table public.treasury_resources enable row level security;
alter table public.treasury_resource_operation_mappings enable row level security;

revoke all on table public.treasury_resource_categories from anon, authenticated;
revoke all on table public.treasury_resources from anon, authenticated;
revoke all on table public.treasury_resource_operation_mappings from anon, authenticated;

grant select, insert, update, delete on table public.treasury_resource_categories to service_role;
grant select, insert, update, delete on table public.treasury_resources to service_role;
grant select, insert, update, delete on table public.treasury_resource_operation_mappings to service_role;

insert into public.treasury_resource_categories (code, name, description)
values
  ('capitalization_reference','Capitalization Reference','Reference materials supporting capitalization design, reserve construction, funding architecture, and capital deployment analysis.'),
  ('settlement_reference','Settlement Reference','Reference materials supporting treasury settlement controls, payment rail analysis, reconciliation, and settlement governance.'),
  ('treasury_intelligence','Treasury Intelligence','Reference materials supporting treasury research, forecasting, liquidity intelligence, risk monitoring, and decision support.')
on conflict (code) do update set name = excluded.name, description = excluded.description, updated_at = now();

insert into public.treasury_resources (category_id, resource_code, title, description, resource_type, lifecycle_status, authoritative_reference, executable_authority, settlement_authority, metadata)
select c.id, v.resource_code, v.title, v.description, 'reference_guide', 'active', false, false, false,
       jsonb_build_object('governance_boundary','reference_not_authority','sourcecube_alignment',v.sourcecube_code)
from (values
  ('capitalization_reference','TR-CAP-001','Treasury Capitalization Reference Guide','Non-executable reference guide for capitalization architecture and capital deployment analysis.','SC-03'),
  ('settlement_reference','TR-SET-001','Treasury Settlement Reference Guide','Non-executable reference guide for treasury settlement controls and reconciliation architecture.','SC-09'),
  ('treasury_intelligence','TR-INT-001','Treasury Intelligence Reference Guide','Non-executable reference guide for treasury intelligence, liquidity monitoring, forecasting, and risk analysis.','SC-11')
) as v(category_code, resource_code, title, description, sourcecube_code)
join public.treasury_resource_categories c on c.code = v.category_code
on conflict (resource_code) do update set
  category_id = excluded.category_id,
  title = excluded.title,
  description = excluded.description,
  resource_type = excluded.resource_type,
  lifecycle_status = excluded.lifecycle_status,
  authoritative_reference = false,
  executable_authority = false,
  settlement_authority = false,
  metadata = excluded.metadata,
  updated_at = now();

insert into public.treasury_resource_operation_mappings (resource_id, sourcecube_code, operation_code, operation_name, relationship_type, execution_permitted, settlement_permitted, notes, metadata)
select r.id, v.sourcecube_code, v.operation_code, v.operation_name, v.relationship_type, false, false,
       'Reference and decision-support linkage only. This mapping does not confer payment, settlement, execution, approval, or signing authority.',
       jsonb_build_object('authority_boundary','non_executable','sourcecube_assignment',v.sourcecube_code)
from (values
  ('TR-CAP-001','SC-03','capitalization_analysis','Capitalization Analysis','decision_support'),
  ('TR-SET-001','SC-09','settlement_control_reference','Settlement Control Reference','control_reference'),
  ('TR-INT-001','SC-11','treasury_intelligence_support','Treasury Intelligence Support','decision_support')
) as v(resource_code, sourcecube_code, operation_code, operation_name, relationship_type)
join public.treasury_resources r on r.resource_code = v.resource_code
on conflict (resource_id, sourcecube_code, operation_code) do update set
  operation_name = excluded.operation_name,
  relationship_type = excluded.relationship_type,
  execution_permitted = false,
  settlement_permitted = false,
  notes = excluded.notes,
  metadata = excluded.metadata,
  updated_at = now();
