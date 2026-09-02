create table if not exists rgl.strategic_regions (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 region_type text not null check(region_type in ('global','priority_region','subregion')),
 parent_region_id uuid references rgl.strategic_regions(id), priority integer not null default 100,
 mandate text, status text not null default 'active' check(status in ('active','planned','inactive')),
 created_at timestamptz not null default now()
);
alter table rgl.strategic_regions enable row level security;

insert into rgl.strategic_regions(code,name,region_type,priority,mandate,status) values
('GLOBAL','Global','global',1,'Global logistics and trade connectivity mandate','active'),
('NAM','North America','priority_region',10,'Primary operating and trade gateway','active'),
('CARIB','Caribbean Basin','priority_region',20,'Strategic regional integration and diaspora trade corridor','active'),
('AFR','Africa','priority_region',30,'Strategic continental trade, development and diaspora corridor','active')
on conflict(code) do update set mandate=excluded.mandate,status=excluded.status,priority=excluded.priority;

update rgl.strategic_regions c set parent_region_id=p.id from rgl.strategic_regions p where p.code='GLOBAL' and c.code in ('NAM','CARIB','AFR');

insert into rgl.strategic_regions(code,name,region_type,parent_region_id,priority,mandate,status)
select v.code,v.name,'subregion',a.id,v.priority,v.mandate,'active' from rgl.strategic_regions a cross join (values
('AFR-W','West Africa',31,'West African trade and diaspora connectivity'),
('AFR-E','East Africa',32,'East African trade and diaspora connectivity'),
('AFR-C','Central Africa',33,'Central African trade and diaspora connectivity'),
('AFR-S','Southern Africa',34,'Southern African trade and diaspora connectivity'),
('AFR-N','North Africa',35,'North African trade and diaspora connectivity')) v(code,name,priority,mandate)
where a.code='AFR' on conflict(code) do update set mandate=excluded.mandate,status='active';

create table if not exists rgl.market_region_memberships (
 id uuid primary key default gen_random_uuid(), market_id uuid not null references wim.markets(id) on delete cascade,
 region_id uuid not null references rgl.strategic_regions(id) on delete cascade,
 classification text not null default 'operating_node', status text not null default 'active', created_at timestamptz not null default now(),
 unique(market_id,region_id)
);
alter table rgl.market_region_memberships enable row level security;

insert into rgl.market_region_memberships(market_id,region_id,classification)
select m.id,r.id,'operating_node' from wim.markets m join rgl.strategic_regions r on
((m.country_code in ('US','CA','MX') and r.code='NAM') or (m.country_code in ('JM','DO','LC') and r.code='CARIB'))
on conflict(market_id,region_id) do update set status='active';

create table if not exists rgl.diaspora_connections (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid references wim.organizations(id),
 residence_market_id uuid references wim.markets(id), heritage_market_id uuid references wim.markets(id),
 residence_region_id uuid references rgl.strategic_regions(id), heritage_region_id uuid references rgl.strategic_regions(id),
 connection_type text not null check(connection_type in ('heritage','family','business','investment','trade','community','institutional')),
 relationship_strength numeric check(relationship_strength between 0 and 1),
 verification_status text not null default 'unverified' check(verification_status in ('unverified','pending','verified','restricted')),
 status text not null default 'active' check(status in ('active','inactive','restricted')),
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table rgl.diaspora_connections enable row level security;
create index if not exists rgl_diaspora_residence_market_idx on rgl.diaspora_connections(residence_market_id);
create index if not exists rgl_diaspora_heritage_market_idx on rgl.diaspora_connections(heritage_market_id);

create table if not exists rgl.logistics_hubs (
 id uuid primary key default gen_random_uuid(), name text not null, hub_type text not null,
 market_id uuid references wim.markets(id), region_id uuid references rgl.strategic_regions(id),
 facility_id uuid references rgl.facilities(id), latitude numeric, longitude numeric,
 status text not null default 'planned' check(status in ('planned','active','inactive')),
 provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table rgl.logistics_hubs enable row level security;

create table if not exists rgl.global_corridor_classes (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 origin_region_id uuid references rgl.strategic_regions(id), destination_region_id uuid references rgl.strategic_regions(id),
 corridor_type text not null, diaspora_enabled boolean not null default true,
 status text not null default 'strategic' check(status in ('strategic','active','planned','inactive')),
 mandate text, created_at timestamptz not null default now()
);
alter table rgl.global_corridor_classes enable row level security;

insert into rgl.global_corridor_classes(code,name,origin_region_id,destination_region_id,corridor_type,status,mandate)
select v.code,v.name,o.id,d.id,v.ctype,v.status,v.mandate
from (values
('NAM-CARIB','North America–Caribbean Basin','NAM','CARIB','multimodal','active','Core diaspora, trade and project logistics corridor'),
('NAM-AFR','North America–Africa','NAM','AFR','multimodal','strategic','Diaspora, trade, investment and development connectivity'),
('CARIB-AFR','Caribbean Basin–Africa','CARIB','AFR','multimodal','strategic','South-South trade and diaspora connectivity'),
('GLOBAL-DIASPORA','Global Diaspora Connectivity','GLOBAL','GLOBAL','network','strategic','Cross-regional diaspora commerce, institutions and community connectivity')) v(code,name,ocode,dcode,ctype,status,mandate)
join rgl.strategic_regions o on o.code=v.ocode join rgl.strategic_regions d on d.code=v.dcode
on conflict(code) do update set mandate=excluded.mandate,status=excluded.status,diaspora_enabled=true;

create or replace view rgl.global_market_topology with (security_invoker=true) as
select r.code region_code,r.name region_name,r.region_type,r.status region_status,
       m.id market_id,m.name market_name,m.country_code,m.status market_status,
       mr.classification
from rgl.strategic_regions r left join rgl.market_region_memberships mr on mr.region_id=r.id
left join wim.markets m on m.id=mr.market_id;

revoke all on rgl.strategic_regions,rgl.market_region_memberships,rgl.diaspora_connections,rgl.logistics_hubs,rgl.global_corridor_classes from anon,authenticated;
revoke all on rgl.global_market_topology from anon,authenticated;
