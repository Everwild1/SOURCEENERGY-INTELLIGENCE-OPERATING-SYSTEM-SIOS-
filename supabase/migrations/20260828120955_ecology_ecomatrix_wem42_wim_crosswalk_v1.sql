create table if not exists ecology.wem42_stage_registry (
  stage_code text primary key,
  stage_number integer not null unique check (stage_number between 1 and 42),
  block_number integer not null check (block_number between 1 and 6),
  block_name text not null,
  stage_name text not null,
  description text not null,
  source_authority text not null default 'WEM-42 — Master Governance & Stage Control Record',
  source_reference text not null default 'google-drive:1zAebSdWwuSDoRMpU9aOD3z3XDeTIwp-KACcEWkpvJxk',
  status text not null default 'canonical',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into ecology.wem42_stage_registry(stage_code,stage_number,block_number,block_name,stage_name,description) values
('WEM-01',1,1,'GENESIS','Community Baseline','Establish verified demographic, economic, institutional, infrastructure, asset, need, and opportunity baselines.'),
('WEM-02',2,1,'GENESIS','Shared Vision','Ratify community priorities and target future state.'),
('WEM-03',3,1,'GENESIS','Structural Barriers','Identify, classify, prioritize, and assign systemic constraints.'),
('WEM-04',4,1,'GENESIS','Response Capacity','Establish intervention teams, capabilities, and response portfolio.'),
('WEM-05',5,1,'GENESIS','Stakeholder Cooperation','Activate accountable household, community, institutional, public, private, and civil-society participation.'),
('WEM-06',6,1,'GENESIS','Pilot Validation','Test priority interventions and document evidence of viability.'),
('WEM-07',7,1,'GENESIS','Genesis Graduation','Certify readiness to enter the Source Block.'),
('WEM-08',8,2,'SOURCE','Productive Resources','Inventory and classify productive resources and underutilized assets.'),
('WEM-09',9,2,'SOURCE','Innovation Pipeline','Establish opportunity discovery, evaluation, incubation, and selection.'),
('WEM-10',10,2,'SOURCE','Value-Chain Interdependence','Connect local production, services, markets, institutions, and external networks.'),
('WEM-11',11,2,'SOURCE','Governance','Establish decision rights, accountability, representation, and oversight.'),
('WEM-12',12,2,'SOURCE','Safeguards & Controls','Implement risk, compliance, integrity, and operating controls.'),
('WEM-13',13,2,'SOURCE','Capital Allocation Discipline','Establish transparent capital priorities and release rules.'),
('WEM-14',14,2,'SOURCE','Source Graduation','Certify resource, governance, and capital readiness.'),
('WEM-15',15,3,'FOUNDATION','Institutional Establishment','Establish or strengthen the entities required to sustain the ecosystem.'),
('WEM-16',16,3,'FOUNDATION','Transparency Infrastructure','Operationalize reporting, disclosure, data, and accountability mechanisms.'),
('WEM-17',17,3,'FOUNDATION','Community Participation','Achieve measurable household and stakeholder participation.'),
('WEM-18',18,3,'FOUNDATION','Economic Foresight','Establish scenario planning, opportunity intelligence, and forward portfolio management.'),
('WEM-19',19,3,'FOUNDATION','Human Capability','Deploy education, workforce, leadership, and enterprise capability pathways.'),
('WEM-20',20,3,'FOUNDATION','Transition & Adoption','Manage resistance, adoption, behavior change, and institutional transition.'),
('WEM-21',21,3,'FOUNDATION','Foundation Graduation','Certify institutional maturity and execution capacity.'),
('WEM-22',22,4,'TIME','Collective Governance','Operationalize distributed and representative governance.'),
('WEM-23',23,4,'TIME','Operating-System Maturity','Achieve reliable, repeatable, measurable operating processes.'),
('WEM-24',24,4,'TIME','Economic Stability','Strengthen household income, enterprise continuity, and economic resilience.'),
('WEM-25',25,4,'TIME','Ethical Wealth Creation','Scale productive wealth while maintaining governance and community benefit.'),
('WEM-26',26,4,'TIME','Network Expansion','Connect the community to regional, national, diaspora, and global networks.'),
('WEM-27',27,4,'TIME','Resilience','Demonstrate preparedness, continuity, adaptation, and recovery capability.'),
('WEM-28',28,4,'TIME','Time Graduation','Certify sustained operating maturity and adaptability.'),
('WEM-29',29,5,'ECOLOGY','Sustainability','Integrate environmental stewardship and resource sustainability into operations.'),
('WEM-30',30,5,'ECOLOGY','Household Well-Being','Improve measurable household quality-of-life outcomes.'),
('WEM-31',31,5,'ECOLOGY','Infrastructure Reliability','Achieve reliable critical physical and digital infrastructure.'),
('WEM-32',32,5,'ECOLOGY','Resource Balance','Optimize production, consumption, reuse, replenishment, and resource flows.'),
('WEM-33',33,5,'ECOLOGY','Community Achievement','Demonstrate sustained enterprise, household, institutional, and social outcomes.'),
('WEM-34',34,5,'ECOLOGY','Equitable Access','Reduce structural gaps in access, participation, opportunity, and ownership.'),
('WEM-35',35,5,'ECOLOGY','Ecology Graduation','Certify integrated economic, social, institutional, and ecological stewardship.'),
('WEM-36',36,6,'EMPIRE','Value Creation at Scale','Expand economic output and productive capacity without compromising governance controls.'),
('WEM-37',37,6,'EMPIRE','Strategic Resource Preservation','Protect strategic community assets and intergenerational value.'),
('WEM-38',38,6,'EMPIRE','Systemic Learning','Institutionalize learning from failures, exceptions, and performance evidence.'),
('WEM-39',39,6,'EMPIRE','Excess & Concentration Controls','Govern extraction, concentration, monopoly risk, and ecosystem imbalance.'),
('WEM-40',40,6,'EMPIRE','Hidden Wealth Activation','Identify and activate overlooked assets, capabilities, knowledge, relationships, and community value.'),
('WEM-41',41,6,'EMPIRE','Strategic Horizon','Maintain a long-range community portfolio, scenarios, and replication roadmap.'),
('WEM-42',42,6,'EMPIRE','Community Wealth Ecology Certification','Consolidate evidence and authorize certification of the complete Wealth Ecology system.')
on conflict (stage_code) do update set stage_name=excluded.stage_name, description=excluded.description, updated_at=now();

create table if not exists ecology.smart_specialization_stage_crosswalk (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  stage_code text not null references ecology.wem42_stage_registry(stage_code),
  mapping_role text not null check (mapping_role in ('entry','enablement','control','outcome','scale')),
  rationale text not null,
  verification_status text not null default 'architectural_crosswalk',
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(node_id,stage_code,mapping_role)
);

create table if not exists ecology.smart_specialization_wim_crosswalk (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  wim_cluster_id bigint not null references wim.economic_clusters(id),
  mapping_role text not null check (mapping_role in ('primary','secondary')),
  rationale text not null,
  verification_status text not null default 'architectural_crosswalk',
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(node_id,wim_cluster_id)
);

create table if not exists ecology.smart_specialization_metric_crosswalk (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  metric_code text not null references wim.impact_metric_registry(metric_code),
  mapping_role text not null check (mapping_role in ('primary','secondary')),
  rationale text not null,
  verification_status text not null default 'architectural_crosswalk',
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(node_id,metric_code)
);

alter table ecology.wem42_stage_registry enable row level security;
alter table ecology.smart_specialization_stage_crosswalk enable row level security;
alter table ecology.smart_specialization_wim_crosswalk enable row level security;
alter table ecology.smart_specialization_metric_crosswalk enable row level security;

insert into ecology.smart_specialization_stage_crosswalk(node_id,stage_code,mapping_role,rationale,provenance)
select n.id,'WEM-09','entry','EcoMatrix specialization enters the governed lifecycle through opportunity discovery, evaluation, incubation, and selection.',jsonb_build_object('method','rule_v1','source','EcoMatrix 2.0 x WEM-42')
from ecology.smart_specialization_nodes n where n.node_type='specialization'
on conflict do nothing;

insert into ecology.smart_specialization_stage_crosswalk(node_id,stage_code,mapping_role,rationale,provenance)
select n.id,
  case n.enablement_layer when 'ENERGY' then 'WEM-31' when 'TECHNOLOGY' then 'WEM-23' when 'EDUCATION' then 'WEM-19' end,
  'enablement',
  case n.enablement_layer when 'ENERGY' then 'Energy specialization is governed as critical physical infrastructure reliability.' when 'TECHNOLOGY' then 'Technology specialization is governed through operating-system maturity and repeatable digital/technical processes.' else 'Education specialization is governed through human capability development.' end,
  jsonb_build_object('method','layer_rule_v1')
from ecology.smart_specialization_nodes n where n.node_type='specialization' and n.enablement_layer in ('ENERGY','TECHNOLOGY','EDUCATION')
on conflict do nothing;

insert into ecology.smart_specialization_stage_crosswalk(node_id,stage_code,mapping_role,rationale,provenance)
select n.id,'WEM-29','control','AIR/LAND/SEA specialization requires environmental stewardship and resource-sustainability control.',jsonb_build_object('method','domain_rule_v1')
from ecology.smart_specialization_nodes n where n.node_type='specialization'
on conflict do nothing;

insert into ecology.smart_specialization_stage_crosswalk(node_id,stage_code,mapping_role,rationale,provenance)
select n.id,'WEM-32','outcome','Distributed, storage, and consumption roles are evaluated through production/consumption/reuse/replenishment resource balance.',jsonb_build_object('method','flow_rule_v1','flow_role',n.flow_role)
from ecology.smart_specialization_nodes n where n.node_type='specialization'
on conflict do nothing;

insert into ecology.smart_specialization_stage_crosswalk(node_id,stage_code,mapping_role,rationale,provenance)
select n.id,'WEM-36','scale','Validated specialization may progress to value creation at scale subject to WEM stage evidence and governance gates.',jsonb_build_object('method','scale_rule_v1')
from ecology.smart_specialization_nodes n where n.node_type='specialization'
on conflict do nothing;

with map(node_code,cluster_code,role,rationale) as (values
('WEM.AIR.EDUCATION.CONSUMPTION.ARVR_KNOWLEDGE_TRANSFER','WIM-T13','primary','Knowledge-transfer specialization aligns to Education and Knowledge Creation.'),
('WEM.AIR.EDUCATION.DISTRIBUTED.COMMUNITY_RESOURCE_CENTERS','WIM-L14','primary','Community resource centers align to Local Community and Civic Organizations.'),
('WEM.AIR.EDUCATION.DISTRIBUTED.COMMUNITY_RESOURCE_CENTERS','WIM-L13','secondary','Education and training is a secondary delivery channel.'),
('WEM.AIR.EDUCATION.STORAGE.CARBON_FOOTPRINT_REDUCTION','WIM-T15','primary','Carbon-footprint reduction aligns to Environmental Services.'),
('WEM.AIR.ENERGY.CONSUMPTION.LIFI_LED','WIM-T27','primary','LiFi/LED specialization aligns to Lighting and Electrical Equipment.'),
('WEM.AIR.ENERGY.DISTRIBUTED.CLEAN_AIR_CO2','WIM-T15','primary','Clean-air and CO2 recovery aligns to Environmental Services.'),
('WEM.AIR.ENERGY.STORAGE.QUANTUM_DOTS','WIM-T23','primary','Quantum-dot technology is provisionally classified with information technology and analytical instruments.'),
('WEM.AIR.TECHNOLOGY.CONSUMPTION.BIG_DATA','WIM-T23','primary','Big Data aligns to Information Technology and Analytical Instruments.'),
('WEM.AIR.TECHNOLOGY.DISTRIBUTED.SAT_MERRA','WIM-T23','primary','Satellite/reanalysis-data specialization aligns to information technology and analytical instrumentation; no external agency relationship is implied.'),
('WEM.AIR.TECHNOLOGY.STORAGE.IP_BLOCKCHAIN_CRYPTO','WIM-T23','primary','Blockchain/IP infrastructure aligns primarily to information technology.'),
('WEM.AIR.TECHNOLOGY.STORAGE.IP_BLOCKCHAIN_CRYPTO','WIM-T16','secondary','Financial-services applications are a secondary market cluster.'),
('WEM.LAND.EDUCATION.CONSUMPTION.KNOWLEDGE_TRANSFER','WIM-T13','primary','Knowledge transfer aligns to Education and Knowledge Creation.'),
('WEM.LAND.EDUCATION.DISTRIBUTED.LAND_MANAGEMENT','WIM-L15','primary','Land management aligns to Local Real Estate, Construction, and Development.'),
('WEM.LAND.EDUCATION.DISTRIBUTED.LAND_MANAGEMENT','WIM-T02','secondary','Agricultural inputs and services provide a secondary land-management market.'),
('WEM.LAND.EDUCATION.STORAGE.ORGANIC_GROWTH','WIM-T02','primary','Organic growth techniques align to Agricultural Inputs and Services.'),
('WEM.LAND.ENERGY.CONSUMPTION.WASTE','WIM-T15','primary','Waste/resource recovery aligns to Environmental Services.'),
('WEM.LAND.ENERGY.DISTRIBUTED.BIO_ELECTRO_MAGNETIC','WIM-T23','primary','Bio-electromagnetic specialization is provisionally classified under analytical instruments pending technical validation.'),
('WEM.LAND.ENERGY.STORAGE.GREEN_ENERGY_SOLUTION','WIM-T14','primary','Green-energy solutions align to Electric Power Generation and Transmission.'),
('WEM.LAND.TECHNOLOGY.CONSUMPTION.ECO_FRIENDLY_INDUSTRIES','WIM-T15','primary','Eco-friendly industrial/community solutions align to Environmental Services.'),
('WEM.LAND.TECHNOLOGY.CONSUMPTION.ECO_FRIENDLY_INDUSTRIES','WIM-L14','secondary','Community organizations are a secondary local cluster.'),
('WEM.LAND.TECHNOLOGY.DISTRIBUTED.BANKING_FUND_STRUCTURE','WIM-T16','primary','Banking and fund structures align to Financial Services.'),
('WEM.LAND.TECHNOLOGY.STORAGE.MERCANTILE_EXCHANGE','WIM-T16','primary','Exchange and market infrastructure aligns to Financial Services.'),
('WEM.LAND.TECHNOLOGY.STORAGE.MERCANTILE_EXCHANGE','WIM-T10','secondary','Distribution and electronic commerce is a secondary exchange-enabled market channel.'),
('WEM.SEA.EDUCATION.CONSUMPTION.MARINE_SCIENCE_AWARENESS','WIM-T13','primary','Marine-science awareness aligns to Education and Knowledge Creation.'),
('WEM.SEA.EDUCATION.DISTRIBUTED.ECO_TOURISM','WIM-T22','primary','Eco-tourism aligns to Hospitality and Tourism.'),
('WEM.SEA.EDUCATION.STORAGE.OCEANOGRAPHY','WIM-T13','primary','Oceanography aligns primarily to Education and Knowledge Creation.'),
('WEM.SEA.EDUCATION.STORAGE.OCEANOGRAPHY','WIM-T23','secondary','Analytical instrumentation and data systems are a secondary oceanography cluster.'),
('WEM.SEA.ENERGY.CONSUMPTION.SEA_LIFE_RESTORATION','WIM-T15','primary','Sea-life restoration aligns to Environmental Services.'),
('WEM.SEA.ENERGY.CONSUMPTION.SEA_LIFE_RESTORATION','WIM-T17','secondary','Fishing and fishing products are a secondary affected economic cluster.'),
('WEM.SEA.ENERGY.DISTRIBUTED.YTTRIUM_HYDRO','WIM-T14','primary','Yttrium Hydro is provisionally classified with electric-power generation pending technical validation.'),
('WEM.SEA.ENERGY.STORAGE.HYDRO_ELECTRIC_INNOVATIONS','WIM-T14','primary','Hydroelectric innovations align to Electric Power Generation and Transmission.'),
('WEM.SEA.TECHNOLOGY.CONSUMPTION.EXISTING_TECH','WIM-T23','primary','Existing-technology reference is classified as a technology/analytical-instrument node; no NASA relationship is asserted.'),
('WEM.SEA.TECHNOLOGY.DISTRIBUTED.ACOUSTIC_INNOVATIONS','WIM-T23','primary','Acoustic innovations align to analytical instruments and information technology.'),
('WEM.SEA.TECHNOLOGY.STORAGE.NATURAL_NITROGEN_RESTORATION','WIM-T15','primary','Nitrogen-restoration concepts align to Environmental Services.')
)
insert into ecology.smart_specialization_wim_crosswalk(node_id,wim_cluster_id,mapping_role,rationale,provenance)
select n.id,c.id,m.role,m.rationale,jsonb_build_object('method','curated_crosswalk_v1','node_code',m.node_code,'cluster_code',m.cluster_code)
from map m join ecology.smart_specialization_nodes n on n.canonical_code=m.node_code join wim.economic_clusters c on c.canonical_code=m.cluster_code
on conflict do nothing;

with map(node_code,metric_code,role,rationale) as (values
('WEM.AIR.EDUCATION.CONSUMPTION.ARVR_KNOWLEDGE_TRANSFER','WEM-KT-001','primary','Measures knowledge-transfer activity.'),
('WEM.AIR.EDUCATION.DISTRIBUTED.COMMUNITY_RESOURCE_CENTERS','WEM-KT-001','primary','Measures knowledge-transfer events delivered through community resource centers.'),
('WEM.AIR.EDUCATION.DISTRIBUTED.COMMUNITY_RESOURCE_CENTERS','WEM-JOBS-001','secondary','Tracks employment created or sustained through center operations.'),
('WEM.AIR.EDUCATION.STORAGE.CARBON_FOOTPRINT_REDUCTION','WEM-ENV-001','primary','Measures environmental impact.'),
('WEM.AIR.ENERGY.CONSUMPTION.LIFI_LED','WEM-PCAP-001','primary','Tracks productive-capacity change from lighting/connectivity infrastructure.'),
('WEM.AIR.ENERGY.CONSUMPTION.LIFI_LED','WEM-ENV-001','secondary','Tracks environmental impact where energy efficiency is demonstrated.'),
('WEM.AIR.ENERGY.DISTRIBUTED.CLEAN_AIR_CO2','WEM-ENV-001','primary','Measures environmental impact of clean-air/CO2 outcomes.'),
('WEM.AIR.ENERGY.STORAGE.QUANTUM_DOTS','WEM-PCAP-001','primary','Tracks productive-capacity change if the technology is validated and deployed.'),
('WEM.AIR.TECHNOLOGY.CONSUMPTION.BIG_DATA','WEM-PCAP-001','primary','Tracks productive-capacity change enabled by analytics.'),
('WEM.AIR.TECHNOLOGY.DISTRIBUTED.SAT_MERRA','WEM-ENV-001','primary','Tracks environmental-impact intelligence applications.'),
('WEM.AIR.TECHNOLOGY.STORAGE.IP_BLOCKCHAIN_CRYPTO','WEM-PCAP-001','primary','Tracks productive-capacity change from digital infrastructure.'),
('WEM.AIR.TECHNOLOGY.STORAGE.IP_BLOCKCHAIN_CRYPTO','WEM-CW-001','secondary','Tracks community-wealth effect where value/ownership infrastructure is deployed.'),
('WEM.LAND.EDUCATION.CONSUMPTION.KNOWLEDGE_TRANSFER','WEM-KT-001','primary','Measures knowledge-transfer activity.'),
('WEM.LAND.EDUCATION.DISTRIBUTED.LAND_MANAGEMENT','WEM-ENV-001','primary','Tracks environmental impact of land stewardship.'),
('WEM.LAND.EDUCATION.STORAGE.ORGANIC_GROWTH','WEM-ENV-001','primary','Tracks environmental impact of organic production practices.'),
('WEM.LAND.ENERGY.CONSUMPTION.WASTE','WEM-ENV-001','primary','Tracks environmental impact of waste reduction/recovery.'),
('WEM.LAND.ENERGY.DISTRIBUTED.BIO_ELECTRO_MAGNETIC','WEM-PCAP-001','primary','Provisional productive-capacity metric pending technical validation.'),
('WEM.LAND.ENERGY.STORAGE.GREEN_ENERGY_SOLUTION','WEM-ENV-001','primary','Tracks environmental impact of validated green-energy deployment.'),
('WEM.LAND.ENERGY.STORAGE.GREEN_ENERGY_SOLUTION','WEM-PCAP-001','secondary','Tracks productive-capacity change from energy infrastructure.'),
('WEM.LAND.TECHNOLOGY.CONSUMPTION.ECO_FRIENDLY_INDUSTRIES','WEM-ENV-001','primary','Tracks environmental impact of eco-friendly production.'),
('WEM.LAND.TECHNOLOGY.CONSUMPTION.ECO_FRIENDLY_INDUSTRIES','WEM-LSP-001','secondary','Tracks local-supplier participation.'),
('WEM.LAND.TECHNOLOGY.DISTRIBUTED.BANKING_FUND_STRUCTURE','WEM-CW-001','primary','Tracks community-wealth effect from financial architecture.'),
('WEM.LAND.TECHNOLOGY.DISTRIBUTED.BANKING_FUND_STRUCTURE','WEM-PCAP-001','secondary','Tracks productive-capacity change associated with capital formation.'),
('WEM.LAND.TECHNOLOGY.STORAGE.MERCANTILE_EXCHANGE','WEM-REGTRADE-001','primary','Tracks regional trade value routed through exchange infrastructure.'),
('WEM.LAND.TECHNOLOGY.STORAGE.MERCANTILE_EXCHANGE','WEM-SME-REV-001','secondary','Tracks SME revenue activated by market access.'),
('WEM.SEA.EDUCATION.CONSUMPTION.MARINE_SCIENCE_AWARENESS','WEM-KT-001','primary','Measures marine-science knowledge-transfer events.'),
('WEM.SEA.EDUCATION.DISTRIBUTED.ECO_TOURISM','WEM-JOBS-001','primary','Tracks jobs created or sustained by eco-tourism.'),
('WEM.SEA.EDUCATION.DISTRIBUTED.ECO_TOURISM','WEM-SME-REV-001','secondary','Tracks SME revenue activated through tourism.'),
('WEM.SEA.EDUCATION.STORAGE.OCEANOGRAPHY','WEM-KT-001','primary','Measures knowledge-transfer outputs from oceanography.'),
('WEM.SEA.ENERGY.CONSUMPTION.SEA_LIFE_RESTORATION','WEM-ENV-001','primary','Tracks environmental impact of marine restoration.'),
('WEM.SEA.ENERGY.DISTRIBUTED.YTTRIUM_HYDRO','WEM-PCAP-001','primary','Provisional productive-capacity metric pending technical validation.'),
('WEM.SEA.ENERGY.DISTRIBUTED.YTTRIUM_HYDRO','WEM-ENV-001','secondary','Environmental impact is required if the technology is validated.'),
('WEM.SEA.ENERGY.STORAGE.HYDRO_ELECTRIC_INNOVATIONS','WEM-PCAP-001','primary','Tracks productive-capacity change from hydroelectric infrastructure.'),
('WEM.SEA.ENERGY.STORAGE.HYDRO_ELECTRIC_INNOVATIONS','WEM-ENV-001','secondary','Tracks environmental impact of hydroelectric deployment.'),
('WEM.SEA.TECHNOLOGY.CONSUMPTION.EXISTING_TECH','WEM-PCAP-001','primary','Tracks productive-capacity effects of validated existing technologies; no external agency relationship is implied.'),
('WEM.SEA.TECHNOLOGY.DISTRIBUTED.ACOUSTIC_INNOVATIONS','WEM-PCAP-001','primary','Tracks productive-capacity change from validated acoustic technology.'),
('WEM.SEA.TECHNOLOGY.STORAGE.NATURAL_NITROGEN_RESTORATION','WEM-ENV-001','primary','Tracks environmental impact of nitrogen-restoration interventions.')
)
insert into ecology.smart_specialization_metric_crosswalk(node_id,metric_code,mapping_role,rationale,provenance)
select n.id,m.metric_code,m.role,m.rationale,jsonb_build_object('method','curated_metric_crosswalk_v1','node_code',m.node_code)
from map m join ecology.smart_specialization_nodes n on n.canonical_code=m.node_code join wim.impact_metric_registry r on r.metric_code=m.metric_code
on conflict do nothing;

create or replace view ecology.smart_specialization_execution_router as
select n.canonical_code as node_code,n.name as node_name,n.domain_code,n.enablement_layer,n.flow_role,
       s.stage_code,sr.stage_name,s.mapping_role as stage_role,
       c.canonical_code as wim_cluster_code,c.name as wim_cluster_name,w.mapping_role as cluster_role,
       m.metric_code,im.metric_name,m.mapping_role as metric_role,
       n.verification_status as node_verification_status
from ecology.smart_specialization_nodes n
left join ecology.smart_specialization_stage_crosswalk s on s.node_id=n.id
left join ecology.wem42_stage_registry sr on sr.stage_code=s.stage_code
left join ecology.smart_specialization_wim_crosswalk w on w.node_id=n.id
left join wim.economic_clusters c on c.id=w.wim_cluster_id
left join ecology.smart_specialization_metric_crosswalk m on m.node_id=n.id
left join wim.impact_metric_registry im on im.metric_code=m.metric_code
where n.node_type='specialization';

