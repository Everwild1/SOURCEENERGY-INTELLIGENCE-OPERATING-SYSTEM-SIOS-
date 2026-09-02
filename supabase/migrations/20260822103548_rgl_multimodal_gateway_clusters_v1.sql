create table if not exists rgl.gateway_clusters (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 geography_id uuid not null references rgl.geography_registry(id), region_id uuid references rgl.strategic_regions(id),
 cluster_type text not null default 'multimodal', status text not null default 'candidate' check(status in ('candidate','qualified','active','inactive')),
 mandate text, created_at timestamptz not null default now()
);
alter table rgl.gateway_clusters enable row level security;

create table if not exists rgl.gateway_cluster_nodes (
 id uuid primary key default gen_random_uuid(), cluster_id uuid not null references rgl.gateway_clusters(id) on delete cascade,
 infrastructure_node_id uuid not null references rgl.infrastructure_nodes(id) on delete cascade,
 node_role text not null default 'gateway', created_at timestamptz not null default now(), unique(cluster_id,infrastructure_node_id)
);
alter table rgl.gateway_cluster_nodes enable row level security;

insert into rgl.gateway_clusters(code,name,geography_id,region_id,mandate)
select v.code,v.name,g.id,r.id,v.mandate from (values
('KINGSTON-MM','Kingston Multimodal Gateway','JM','CARIB','Caribbean Basin ocean-air consolidation and Diaspora gateway'),
('ACCRA-TEMA-MM','Accra–Tema Multimodal Gateway','GH','AFR-W','West Africa ocean-air trade and Diaspora gateway'),
('LAGOS-MM','Lagos Multimodal Gateway','NG','AFR-W','West Africa ocean-air commercial and Diaspora gateway')) v(code,name,cc,rc,mandate)
join rgl.geography_registry g on g.iso_alpha2=v.cc join rgl.strategic_regions r on r.code=v.rc
on conflict(code) do update set mandate=excluded.mandate;

insert into rgl.gateway_cluster_nodes(cluster_id,infrastructure_node_id,node_role)
select c.id,n.id,case when n.node_type='seaport' then 'ocean_gateway' else 'air_gateway' end
from rgl.gateway_clusters c join rgl.geography_registry g on g.id=c.geography_id join rgl.infrastructure_nodes n on n.geography_id=g.id
where (c.code='KINGSTON-MM' and n.name in ('Port of Kingston / Kingston Container Terminal','Norman Manley International Airport'))
   or (c.code='ACCRA-TEMA-MM' and n.name in ('Port of Tema','Kotoka International Airport'))
   or (c.code='LAGOS-MM' and n.name in ('Lagos Port Complex (Apapa)','Murtala Muhammed International Airport'))
on conflict(cluster_id,infrastructure_node_id) do nothing;

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,evidence)
select o.id,d.id,c.id,'ocean','North America–Caribbean Basin ocean gateway candidate',jsonb_build_object('basis','verified destination seaport; North American origin port qualification pending')
from rgl.infrastructure_nodes o,rgl.infrastructure_nodes d,rgl.global_corridor_classes c
where o.name='Port of Kingston / Kingston Container Terminal' and d.name='Port of Tema' and c.code='CARIB-AFR'
on conflict do nothing;

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,evidence)
select o.id,d.id,c.id,'ocean','Caribbean Basin–West Africa ocean gateway candidate',jsonb_build_object('basis','verified external seaport nodes; commercial service qualification pending')
from rgl.infrastructure_nodes o,rgl.infrastructure_nodes d,rgl.global_corridor_classes c
where o.name='Port of Kingston / Kingston Container Terminal' and d.name='Lagos Port Complex (Apapa)' and c.code='CARIB-AFR'
on conflict do nothing;

create or replace view rgl.multimodal_gateway_network with (security_invoker=true) as
select c.code cluster_code,c.name cluster_name,c.status,c.mandate,g.country_name,g.rgl_region_code,
       count(n.id) node_count,array_agg(n.node_type order by n.node_type) node_types
from rgl.gateway_clusters c join rgl.geography_registry g on g.id=c.geography_id
left join rgl.gateway_cluster_nodes cn on cn.cluster_id=c.id left join rgl.infrastructure_nodes n on n.id=cn.infrastructure_node_id
group by c.code,c.name,c.status,c.mandate,g.country_name,g.rgl_region_code;

revoke all on rgl.gateway_clusters,rgl.gateway_cluster_nodes,rgl.multimodal_gateway_network from anon,authenticated;
