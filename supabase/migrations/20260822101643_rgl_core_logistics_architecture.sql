create schema if not exists rgl;

create table rgl.organizations (
 id uuid primary key default gen_random_uuid(),
 setc_organization_id text,
 legal_name text not null,
 display_name text not null,
 organization_type text not null default 'logistics_operator',
 jurisdiction_code text,
 website_url text,
 verification_status text not null default 'internal',
 provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index rgl_organizations_legal_name_uq on rgl.organizations(lower(legal_name));

create table rgl.corridors (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 origin_region text, destination_region text, mode text, status text not null default 'planned',
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.facilities (
 id uuid primary key default gen_random_uuid(), organization_id uuid references rgl.organizations(id),
 name text not null, facility_type text not null, country_code text, locality text, latitude numeric, longitude numeric,
 status text not null default 'planned', provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.carriers (
 id uuid primary key default gen_random_uuid(), organization_id uuid references rgl.organizations(id), legal_name text not null,
 dot_number text, mc_number text, carrier_type text, status text not null default 'prospect', compliance_status text,
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.fleet_assets (
 id uuid primary key default gen_random_uuid(), carrier_id uuid references rgl.carriers(id), asset_type text not null,
 asset_identifier text, make text, model text, model_year integer, ownership_type text, status text not null default 'available',
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.projects (
 id uuid primary key default gen_random_uuid(), external_project_id text, name text not null, project_type text,
 country_code text, status text not null default 'planned', provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

create table rgl.contracts (
 id uuid primary key default gen_random_uuid(), project_id uuid references rgl.projects(id), customer_organization_id uuid references rgl.organizations(id),
 contract_reference text, contract_type text, status text not null default 'draft', start_date date, end_date date,
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.orders (
 id uuid primary key default gen_random_uuid(), external_order_id text, wim_transaction_id uuid,
 customer_organization_id uuid references rgl.organizations(id), project_id uuid references rgl.projects(id), contract_id uuid references rgl.contracts(id),
 order_type text not null default 'freight', status text not null default 'created', requested_pickup_at timestamptz, requested_delivery_at timestamptz,
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.shipments (
 id uuid primary key default gen_random_uuid(), order_id uuid references rgl.orders(id), corridor_id uuid references rgl.corridors(id),
 shipment_reference text unique not null, mode text not null default 'road', status text not null default 'planned',
 origin_facility_id uuid references rgl.facilities(id), destination_facility_id uuid references rgl.facilities(id),
 planned_departure_at timestamptz, planned_arrival_at timestamptz, actual_departure_at timestamptz, actual_arrival_at timestamptz,
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table rgl.loads (
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references rgl.shipments(id) on delete cascade,
 carrier_id uuid references rgl.carriers(id), fleet_asset_id uuid references rgl.fleet_assets(id), load_reference text,
 status text not null default 'planned', weight_kg numeric, volume_m3 numeric, provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

create table rgl.tracking_events (
 id bigint generated always as identity primary key, shipment_id uuid not null references rgl.shipments(id) on delete cascade,
 load_id uuid references rgl.loads(id) on delete cascade, event_type text not null, event_at timestamptz not null default now(),
 latitude numeric, longitude numeric, source text, evidence_reference text, payload jsonb not null default '{}'::jsonb
);
create index rgl_tracking_events_shipment_at_idx on rgl.tracking_events(shipment_id,event_at desc);

create table rgl.documents (
 id uuid primary key default gen_random_uuid(), shipment_id uuid references rgl.shipments(id) on delete cascade,
 contract_id uuid references rgl.contracts(id), document_type text not null, external_uri text, checksum text,
 verification_status text not null default 'unverified', metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.customs_events (
 id bigint generated always as identity primary key, shipment_id uuid not null references rgl.shipments(id) on delete cascade,
 country_code text, event_type text not null, status text, event_at timestamptz not null default now(), reference text, payload jsonb not null default '{}'::jsonb
);

create table rgl.delivery_evidence (
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references rgl.shipments(id) on delete cascade,
 evidence_type text not null, evidence_reference text, captured_at timestamptz not null default now(), verified_at timestamptz,
 verifier text, metadata jsonb not null default '{}'::jsonb
);

create table rgl.invoices (
 id uuid primary key default gen_random_uuid(), order_id uuid references rgl.orders(id), shipment_id uuid references rgl.shipments(id),
 invoice_reference text, currency text not null default 'USD', amount numeric(18,2) not null default 0, status text not null default 'draft',
 issued_at timestamptz, due_at timestamptz, paid_at timestamptz, provenance jsonb not null default '{}'::jsonb
);

create table rgl.incidents (
 id uuid primary key default gen_random_uuid(), shipment_id uuid references rgl.shipments(id), fleet_asset_id uuid references rgl.fleet_assets(id),
 incident_type text not null, severity text, status text not null default 'open', occurred_at timestamptz not null default now(),
 description text, metadata jsonb not null default '{}'::jsonb
);

create table rgl.compliance_records (
 id uuid primary key default gen_random_uuid(), carrier_id uuid references rgl.carriers(id), fleet_asset_id uuid references rgl.fleet_assets(id),
 record_type text not null, authority text, reference text, status text not null default 'pending', valid_from date, valid_until date,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table rgl.economic_events (
 id uuid primary key default gen_random_uuid(), organization_id uuid references rgl.organizations(id), project_id uuid references rgl.projects(id),
 order_id uuid references rgl.orders(id), shipment_id uuid references rgl.shipments(id), event_type text not null,
 occurred_at timestamptz not null default now(), currency text, amount numeric(18,2), source_system text not null default 'rgl',
 external_reference text, payload jsonb not null default '{}'::jsonb
);
create index rgl_economic_events_shipment_idx on rgl.economic_events(shipment_id,occurred_at desc);

insert into rgl.organizations(legal_name,display_name,organization_type,jurisdiction_code,website_url,verification_status,provenance)
values ('Robert Global Logistics LLC','Robert Global Logistics','logistics_operator','US-VA','https://www.robertlogix.com','drive_verified',jsonb_build_object('source','SourceEnergy Drive','phase','Phase I'))
on conflict do nothing;

insert into rgl.corridors(code,name,origin_region,destination_region,mode,status,provenance) values
('RGL-R1-CUSM','Canada–United States–Mexico','North America','North America','road','phase_1',jsonb_build_object('source','RGL canonical financial pro forma')),
('RGL-CAR-JAM','Caribbean – Jamaica','North America','Jamaica','multimodal','phase_2',jsonb_build_object('source','RGL canonical financial pro forma')),
('RGL-CAR-DOM','Caribbean – Dominican Republic','North America','Dominican Republic','multimodal','phase_2',jsonb_build_object('source','RGL canonical financial pro forma')),
('RGL-CAR-LCA','Caribbean – Saint Lucia','North America','Saint Lucia','multimodal','phase_2',jsonb_build_object('source','RGL canonical financial pro forma'))
on conflict (code) do nothing;
