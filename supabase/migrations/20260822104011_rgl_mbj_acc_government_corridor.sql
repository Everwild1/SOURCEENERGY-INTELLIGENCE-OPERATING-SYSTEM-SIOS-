create table if not exists rgl.government_corridor_mandates (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 origin_country_code text not null, destination_country_code text not null,
 instrument_type text not null, instrument_status text not null,
 policy_status text not null, implementation_status text not null,
 signed_year integer, government_parties text[] not null default '{}',
 source_authority text, source_reference text, secondary_source_reference text,
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table rgl.government_corridor_mandates enable row level security;

insert into rgl.infrastructure_nodes(geography_id,name,node_type,iata_code,icao_code,verification_status,source_authority,source_reference,status)
select g.id,'Sangster International Airport','airport','MBJ','MKJS','verified','Airports Authority of Jamaica / MBJ Airports Limited','https://www.mbjairport.com/','candidate'
from rgl.geography_registry g where g.iso_alpha2='JM'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Sangster International Airport');

insert into rgl.government_corridor_mandates(code,name,origin_country_code,destination_country_code,instrument_type,instrument_status,policy_status,implementation_status,signed_year,government_parties,source_authority,source_reference,secondary_source_reference,notes)
values ('JM-GH-ASA','Jamaica–Ghana Bilateral Air Services Framework','JM','GH','bilateral_air_services_agreement','signed_pending_full_operationalization','government_backed','implementation_planning',2018,array['Government of Jamaica','Government of Ghana'],'Government of Jamaica / Government of Ghana','https://jis.gov.jm/jamaica-and-ghana-to-expand-bilateral-cooperation-in-key-areas/','https://mfa.gov.gh/index.php/as-part-of-his-historic-state-visit-to-jamaica-president-john-dramani-mahama-held-bilateral-talks-on-monday-3rd-august-2026-with-the-most-honourable-dr-andrew-holness-prime-minister-of-jamaica/','Government statements in August 2026 identify parliamentary fast-tracking in Ghana and direct Accra–Montego Bay service as the intended operational outcome.')
on conflict(code) do update set instrument_status=excluded.instrument_status,policy_status=excluded.policy_status,implementation_status=excluded.implementation_status,source_reference=excluded.source_reference,secondary_source_reference=excluded.secondary_source_reference,notes=excluded.notes,updated_at=now();

insert into rgl.gateway_route_candidates(origin_node_id,destination_node_id,corridor_class_id,transport_mode,strategic_use,status,evidence)
select mbj.id,acc.id,c.id,'air','Government-backed Jamaica–Ghana direct air connectivity; Diaspora, tourism, trade, investment and cargo corridor','qualified',jsonb_build_object('government_mandate','JM-GH-ASA','policy_status','government_backed','implementation_status','implementation_planning','direct_service_status','not_yet_operational','sources',jsonb_build_array('Jamaica Information Service 2026-08-05','Ghana Ministry of Foreign Affairs 2026-08-04'))
from rgl.infrastructure_nodes mbj,rgl.infrastructure_nodes acc,rgl.global_corridor_classes c
where mbj.name='Sangster International Airport' and acc.name='Kotoka International Airport' and c.code='CARIB-AFR'
on conflict(origin_node_id,destination_node_id,transport_mode) do update set strategic_use=excluded.strategic_use,status='qualified',evidence=excluded.evidence;

create table if not exists rgl.route_government_mandate_links (
 id uuid primary key default gen_random_uuid(), route_candidate_id uuid not null references rgl.gateway_route_candidates(id) on delete cascade,
 mandate_id uuid not null references rgl.government_corridor_mandates(id) on delete cascade,
 relationship_type text not null default 'enabling_instrument', created_at timestamptz not null default now(),
 unique(route_candidate_id,mandate_id)
);
alter table rgl.route_government_mandate_links enable row level security;

insert into rgl.route_government_mandate_links(route_candidate_id,mandate_id)
select r.id,m.id from rgl.gateway_route_candidates r join rgl.infrastructure_nodes o on o.id=r.origin_node_id join rgl.infrastructure_nodes d on d.id=r.destination_node_id cross join rgl.government_corridor_mandates m
where o.iata_code='MBJ' and d.iata_code='ACC' and r.transport_mode='air' and m.code='JM-GH-ASA'
on conflict do nothing;

revoke all on rgl.government_corridor_mandates,rgl.route_government_mandate_links from anon,authenticated;
