create table if not exists rgl.rail_networks (
 id uuid primary key default gen_random_uuid(), name text not null, operator_organization_id uuid references wim.organizations(id), country_code text,
 network_type text not null default 'freight', status text not null default 'candidate', provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists rgl.rail_terminals (
 id uuid primary key default gen_random_uuid(), network_id uuid references rgl.rail_networks(id), infrastructure_node_id uuid references rgl.infrastructure_nodes(id),
 name text not null, terminal_type text not null default 'intermodal', status text not null default 'candidate', created_at timestamptz not null default now()
);
create table if not exists rgl.rail_segments (
 id uuid primary key default gen_random_uuid(), network_id uuid references rgl.rail_networks(id), origin_terminal_id uuid references rgl.rail_terminals(id), destination_terminal_id uuid references rgl.rail_terminals(id),
 segment_reference text, distance_km numeric, status text not null default 'candidate', provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists rgl.intermodal_connections (
 id uuid primary key default gen_random_uuid(), from_node_id uuid not null references rgl.infrastructure_nodes(id), to_node_id uuid not null references rgl.infrastructure_nodes(id),
 connection_mode text not null check(connection_mode in ('rail-road','rail-ocean','rail-air','road-ocean','road-air','drone-road','drone-air','multimodal')),
 status text not null default 'candidate', transfer_notes text, provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(from_node_id,to_node_id,connection_mode)
);

create table if not exists rgl.drone_fleets (
 id uuid primary key default gen_random_uuid(), organization_id uuid references rgl.organizations(id), name text not null, operator_name text,
 jurisdiction_code text, status text not null default 'planned', provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists rgl.drone_hubs (
 id uuid primary key default gen_random_uuid(), fleet_id uuid references rgl.drone_fleets(id), name text not null, facility_id uuid references rgl.facilities(id), infrastructure_node_id uuid references rgl.infrastructure_nodes(id),
 latitude numeric, longitude numeric, status text not null default 'planned', created_at timestamptz not null default now()
);
create table if not exists rgl.drone_delivery_zones (
 id uuid primary key default gen_random_uuid(), hub_id uuid references rgl.drone_hubs(id), name text not null, jurisdiction_code text,
 max_payload_kg numeric, max_radius_km numeric, regulatory_status text not null default 'unverified', status text not null default 'planned', provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists rgl.drone_missions (
 id uuid primary key default gen_random_uuid(), shipment_id uuid references rgl.shipments(id), hub_id uuid references rgl.drone_hubs(id), zone_id uuid references rgl.drone_delivery_zones(id),
 mission_reference text unique, status text not null default 'planned', payload_kg numeric, planned_departure_at timestamptz, completed_at timestamptz,
 regulatory_authorization_reference text, provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists rgl.drone_telemetry_events (
 id bigint generated always as identity primary key, mission_id uuid not null references rgl.drone_missions(id) on delete cascade, event_at timestamptz not null default now(),
 latitude numeric, longitude numeric, altitude_m numeric, event_type text not null, payload jsonb not null default '{}'::jsonb
);

create table if not exists rgl.spatial_registry_links (
 id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id uuid not null,
 spatial_registry_id text, geometry_type text, latitude numeric, longitude numeric, jurisdiction_code text,
 economic_cluster_id uuid references rgl.economic_clusters(id), verification_status text not null default 'pending',
 source_system text not null default 'sourceenergy_spatial_registry', source_reference text, provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(entity_type,entity_id,source_system)
);
create index if not exists rgl_spatial_registry_id_idx on rgl.spatial_registry_links(spatial_registry_id);
create index if not exists rgl_spatial_entity_idx on rgl.spatial_registry_links(entity_type,entity_id);

create table if not exists rgl.spatial_event_links (
 id uuid primary key default gen_random_uuid(), spatial_link_id uuid not null references rgl.spatial_registry_links(id) on delete cascade,
 tracking_event_id bigint references rgl.tracking_events(id) on delete cascade, economic_event_id uuid references rgl.economic_events(id) on delete cascade,
 event_role text not null default 'location_context', created_at timestamptz not null default now()
);

insert into rgl.spatial_registry_links(entity_type,entity_id,geometry_type,latitude,longitude,jurisdiction_code,verification_status,source_reference,provenance)
select 'infrastructure_node',n.id,'point',n.latitude,n.longitude,g.iso_alpha2,'pending',n.source_reference,jsonb_build_object('bootstrap','RGL infrastructure registry','node_type',n.node_type)
from rgl.infrastructure_nodes n join rgl.geography_registry g on g.id=n.geography_id
on conflict(entity_type,entity_id,source_system) do update set source_reference=excluded.source_reference,updated_at=now();

create or replace view rgl.mobility_network_summary with (security_invoker=true) as
select
 (select count(*) from rgl.infrastructure_nodes where node_type='seaport') seaports,
 (select count(*) from rgl.infrastructure_nodes where node_type='airport') airports,
 (select count(*) from rgl.infrastructure_nodes where node_type='rail_terminal') rail_terminals,
 (select count(*) from rgl.rail_segments) rail_segments,
 (select count(*) from rgl.drone_hubs) drone_hubs,
 (select count(*) from rgl.drone_missions) drone_missions,
 (select count(*) from rgl.spatial_registry_links) spatial_links;

do $$ declare t text; begin foreach t in array array['rail_networks','rail_terminals','rail_segments','intermodal_connections','drone_fleets','drone_hubs','drone_delivery_zones','drone_missions','drone_telemetry_events','spatial_registry_links','spatial_event_links'] loop execute format('alter table rgl.%I enable row level security',t); execute format('revoke all on rgl.%I from anon, authenticated',t); end loop; end $$;
revoke all on rgl.mobility_network_summary from anon,authenticated;
