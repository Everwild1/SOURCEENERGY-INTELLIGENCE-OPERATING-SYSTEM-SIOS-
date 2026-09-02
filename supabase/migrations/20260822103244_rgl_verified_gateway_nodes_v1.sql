insert into rgl.infrastructure_nodes(geography_id,name,node_type,verification_status,source_authority,source_reference,status)
select g.id,'Port of Kingston / Kingston Container Terminal','seaport','verified','Port Authority of Jamaica / Jamaica Government','https://jis.gov.jm/government/agencies/port-authority-of-jamaica/','candidate'
from rgl.geography_registry g where g.iso_alpha2='JM'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Port of Kingston / Kingston Container Terminal');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,verification_status,source_authority,source_reference,status)
select g.id,'Port of Tema','seaport','verified','Ghana Ports and Harbours Authority','https://www.ghanaports.gov.gh/page/index/4/ZE4GGQFA/Welcome-to-Port-Of-Tema','candidate'
from rgl.geography_registry g where g.iso_alpha2='GH'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Port of Tema');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,verification_status,source_authority,source_reference,status)
select g.id,'Lagos Port Complex (Apapa)','seaport','verified','Nigerian Ports Authority','https://nigerianports.gov.ng/lagos-port/','candidate'
from rgl.geography_registry g where g.iso_alpha2='NG'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Lagos Port Complex (Apapa)');

insert into rgl.infrastructure_nodes(geography_id,name,node_type,verification_status,source_authority,source_reference,status)
select g.id,'Port of Mombasa','seaport','verified','Kenya Ports Authority','https://www.kpa.co.ke/Ports/PortOfMombasa','candidate'
from rgl.geography_registry g where g.iso_alpha2='KE'
and not exists(select 1 from rgl.infrastructure_nodes n where n.geography_id=g.id and n.name='Port of Mombasa');

create or replace view rgl.verified_gateway_network with (security_invoker=true) as
select n.id,n.name,n.node_type,n.status,n.verification_status,g.country_name,g.iso_alpha2,g.rgl_region_code,n.source_authority,n.source_reference
from rgl.infrastructure_nodes n join rgl.geography_registry g on g.id=n.geography_id
where n.verification_status='verified';

revoke all on rgl.verified_gateway_network from anon,authenticated;
