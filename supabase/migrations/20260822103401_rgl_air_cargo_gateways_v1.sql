insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Miami International Airport','airport','MIA','KMIA','verified','Miami-Dade Aviation Department','https://www.miami-airport.com/home-cargo.asp','candidate'
from rgl.geography_registry g where g.iso_alpha2='US'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Miami International Airport');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'John F. Kennedy International Airport','airport','JFK','KJFK','verified','Port Authority of New York and New Jersey','https://www.panynj.gov/airports/en/index.html','candidate'
from rgl.geography_registry g where g.iso_alpha2='US'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='John F. Kennedy International Airport');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Toronto Pearson International Airport','airport','YYZ','CYYZ','verified','Greater Toronto Airports Authority','https://www.torontopearson.com/en/corporate/partnering-with-us/cargo-services','candidate'
from rgl.geography_registry g where g.iso_alpha2='CA'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Toronto Pearson International Airport');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Norman Manley International Airport','airport','KIN','MKJP','verified','Norman Manley International Airport / Airports Authority of Jamaica','https://nmia.aero/business/cargo-business/','candidate'
from rgl.geography_registry g where g.iso_alpha2='JM'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Norman Manley International Airport');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Kotoka International Airport','airport','ACC','DGAA','verified','Ghana Airports Company Limited','https://www.gacl.com.gh/kia-history/','candidate'
from rgl.geography_registry g where g.iso_alpha2='GH'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Kotoka International Airport');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Murtala Muhammed International Airport','airport','LOS','DNMM','verified','Federal Airports Authority of Nigeria','https://faan.gov.ng/','candidate'
from rgl.geography_registry g where g.iso_alpha2='NG'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Murtala Muhammed International Airport');

create table if not exists rgl.gateway_route_candidates (
 id uuid primary key default gen_random_uuid(),
 origin_node_id uuid not null references rgl.infrastructure_nodes(id) on delete cascade,
 destination_node_id uuid not null references rgl.infrastructure_nodes(id) on delete cascade,
 corridor_class_id uuid references rgl.global_corridor_classes(id),
 transport_mode text not null check(transport_mode in ('air','ocean','road','rail','multimodal')),
 strategic_use text not null,
 status text not null default 'candidate' check(status in ('candidate','qualified','active','inactive')),
 evidence jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(origin_node_id,destination_node_id,transport_mode)
);
alter table rgl.gateway_route_candidates enable row level security;

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,evidence)
select o.id,d.id,c.id,'air','Diaspora and commercial air-cargo gateway candidate',jsonb_build_object('basis','verified cargo-capable gateway nodes')
from rgl.infrastructure_nodes o,rgl.infrastructure_nodes d,rgl.global_corridor_classes c
where o.name='Miami International Airport' and d.name='Norman Manley International Airport' and c.code='NAM-CARIB'
on conflict do nothing;

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,evidence)
select o.id,d.id,c.id,'air','North America–West Africa air-cargo gateway candidate',jsonb_build_object('basis','verified cargo-capable gateway nodes')
from rgl.infrastructure_nodes o,rgl.infrastructure_nodes d,rgl.global_corridor_classes c
where o.name='John F. Kennedy International Airport' and d.name='Kotoka International Airport' and c.code='NAM-AFR'
on conflict do nothing;

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,evidence)
select o.id,d.id,c.id,'air','North America–West Africa air-cargo gateway candidate',jsonb_build_object('basis','verified cargo-capable gateway nodes')
from rgl.infrastructure_nodes o,rgl.infrastructure_nodes d,rgl.global_corridor_classes c
where o.name='Toronto Pearson International Airport' and d.name='Murtala Muhammed International Airport' and c.code='NAM-AFR'
on conflict do nothing;

revoke all on rgl.gateway_route_candidates from anon,authenticated;
