create table if not exists rgl.economic_clusters (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 region_id uuid references rgl.strategic_regions(id), market_id uuid references wim.markets(id),
 cluster_type text not null, sector_tags text[] not null default '{}', status text not null default 'planned',
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table rgl.economic_clusters enable row level security;

create table if not exists rgl.corridor_intelligence (
 id uuid primary key default gen_random_uuid(), corridor_class_id uuid references rgl.global_corridor_classes(id),
 wim_trade_corridor_id uuid references wim.trade_corridors(id), assessed_at timestamptz not null default now(),
 trade_potential_score numeric check(trade_potential_score between 0 and 100),
 diaspora_connectivity_score numeric check(diaspora_connectivity_score between 0 and 100),
 infrastructure_readiness_score numeric check(infrastructure_readiness_score between 0 and 100),
 regulatory_complexity_score numeric check(regulatory_complexity_score between 0 and 100),
 resilience_score numeric check(resilience_score between 0 and 100),
 overall_priority_score numeric check(overall_priority_score between 0 and 100),
 evidence jsonb not null default '{}'::jsonb, status text not null default 'unscored',
 unique(corridor_class_id,wim_trade_corridor_id)
);
alter table rgl.corridor_intelligence enable row level security;

create table if not exists rgl.network_opportunity_links (
 id uuid primary key default gen_random_uuid(),
 opportunity_id uuid references wim.opportunities(id) on delete cascade,
 corridor_class_id uuid references rgl.global_corridor_classes(id),
 economic_cluster_id uuid references rgl.economic_clusters(id),
 logistics_readiness text not null default 'assessment' check(logistics_readiness in ('assessment','qualified','planned','execution','completed','blocked')),
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
 unique(opportunity_id,corridor_class_id,economic_cluster_id)
);
alter table rgl.network_opportunity_links enable row level security;

create table if not exists rgl.wealth_ecology_impacts (
 id uuid primary key default gen_random_uuid(), economic_event_id uuid references rgl.economic_events(id) on delete cascade,
 shipment_id uuid references rgl.shipments(id), project_id uuid references rgl.projects(id),
 market_id uuid references wim.markets(id), region_id uuid references rgl.strategic_regions(id),
 impact_dimension text not null check(impact_dimension in ('trade','enterprise','employment','infrastructure','community','diaspora','resilience','capital')),
 metric_code text not null, metric_value numeric, metric_unit text, evidence_reference text,
 verification_status text not null default 'unverified' check(verification_status in ('unverified','pending','verified','rejected')),
 measured_at timestamptz not null default now(), provenance jsonb not null default '{}'::jsonb
);
alter table rgl.wealth_ecology_impacts enable row level security;
create index if not exists rgl_wealth_ecology_region_idx on rgl.wealth_ecology_impacts(region_id,measured_at desc);
create index if not exists rgl_wealth_ecology_shipment_idx on rgl.wealth_ecology_impacts(shipment_id,measured_at desc);

create or replace view rgl.network_intelligence_summary with (security_invoker=true) as
select r.code region_code,r.name region_name,
 count(distinct mr.market_id) market_nodes,
 count(distinct lh.id) logistics_hubs,
 count(distinct ec.id) economic_clusters,
 count(distinct dc.id) diaspora_connections
from rgl.strategic_regions r
left join rgl.market_region_memberships mr on mr.region_id=r.id
left join rgl.logistics_hubs lh on lh.region_id=r.id
left join rgl.economic_clusters ec on ec.region_id=r.id
left join rgl.diaspora_connections dc on dc.residence_region_id=r.id or dc.heritage_region_id=r.id
group by r.code,r.name;

revoke all on rgl.economic_clusters,rgl.corridor_intelligence,rgl.network_opportunity_links,rgl.wealth_ecology_impacts from anon,authenticated;
revoke all on rgl.network_intelligence_summary from anon,authenticated;
