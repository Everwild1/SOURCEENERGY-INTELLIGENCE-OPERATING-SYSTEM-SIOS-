create table if not exists ecology.smart_specialization_domains (
  domain_code text primary key,
  name text not null,
  description text,
  status text not null default 'active' check (status in ('active','inactive','deprecated')),
  source_authority text not null,
  source_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists ecology.smart_specialization_nodes (
  id uuid primary key default gen_random_uuid(),
  canonical_code text not null unique,
  name text not null,
  domain_code text not null references ecology.smart_specialization_domains(domain_code),
  node_type text not null check (node_type in ('specialization','domain_outcome','policy_principle')),
  enablement_layer text check (enablement_layer in ('ENERGY','TECHNOLOGY','EDUCATION')),
  flow_role text check (flow_role in ('DISTRIBUTED','STORAGE','CONSUMPTION')),
  conceptual_status text not null default 'conceptual' check (conceptual_status in ('conceptual','candidate','validated','operational','retired')),
  verification_status text not null default 'unverified' check (verification_status in ('unverified','partially_verified','verified','disputed')),
  source_authority text not null,
  source_reference text,
  evidence_reference text,
  description text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(domain_code, name)
);

create table if not exists ecology.smart_specialization_links (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  target_domain text not null,
  target_schema text,
  target_object_type text not null,
  target_object_id text,
  relationship_type text not null,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','partially_verified','verified','disputed')),
  evidence_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists smart_specialization_nodes_domain_idx on ecology.smart_specialization_nodes(domain_code);
create index if not exists smart_specialization_nodes_layer_idx on ecology.smart_specialization_nodes(enablement_layer, flow_role);
create index if not exists smart_specialization_links_node_idx on ecology.smart_specialization_links(node_id);
create index if not exists smart_specialization_links_target_idx on ecology.smart_specialization_links(target_domain, target_schema, target_object_type);

insert into ecology.smart_specialization_domains(domain_code,name,description,source_authority,source_reference,provenance)
values
 ('AIR','Air','Atmospheric, climate, communications and clean-air smart-specialization domain.','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"artifact":"Wealth·Eco Matrix — Smart Specialization","version":"source artifact"}'::jsonb),
 ('LAND','Land','Terrestrial, health, agriculture, finance, industry and land-management smart-specialization domain.','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"artifact":"Wealth·Eco Matrix — Smart Specialization","version":"source artifact"}'::jsonb),
 ('SEA','Sea','Marine, water, hydro, restoration, ocean science and eco-tourism smart-specialization domain.','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"artifact":"Wealth·Eco Matrix — Smart Specialization","version":"source artifact"}'::jsonb)
on conflict (domain_code) do update set name=excluded.name, description=excluded.description, source_reference=excluded.source_reference, updated_at=now();

insert into ecology.smart_specialization_nodes(canonical_code,name,domain_code,node_type,enablement_layer,flow_role,source_authority,source_reference,provenance)
values
 ('WEM.AIR.OUTCOME.ENV_HEALTH','Environmental Health','AIR','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Environmental Health"}'::jsonb),
 ('WEM.AIR.OUTCOME.GLOBAL_WARMING_COMBAT','Global Warming Combat','AIR','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.OUTCOME.COMMUNICATION','Communication','AIR','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.ENERGY.DISTRIBUTED.CLEAN_AIR_CO2','Clean Air / CO2 Recovery','AIR','specialization','ENERGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Clean Air | Co2 Recovery"}'::jsonb),
 ('WEM.AIR.ENERGY.STORAGE.QUANTUM_DOTS','Quantum Dots','AIR','specialization','ENERGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.ENERGY.CONSUMPTION.LIFI_LED','Lighting Fidelity / LiFi / LED Light','AIR','specialization','ENERGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Lighting Fidelity- LiFi/LED Light"}'::jsonb),
 ('WEM.AIR.TECHNOLOGY.DISTRIBUTED.SAT_MERRA','SAT / MERRA','AIR','specialization','TECHNOLOGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"SAT | MERRA"}'::jsonb),
 ('WEM.AIR.TECHNOLOGY.STORAGE.IP_BLOCKCHAIN_CRYPTO','IP Blockchain / Crypto','AIR','specialization','TECHNOLOGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"IP Block Chain | CRYPTO"}'::jsonb),
 ('WEM.AIR.TECHNOLOGY.CONSUMPTION.BIG_DATA','Big Data','AIR','specialization','TECHNOLOGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.EDUCATION.DISTRIBUTED.COMMUNITY_RESOURCE_CENTERS','Community Resource Centers','AIR','specialization','EDUCATION','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.EDUCATION.STORAGE.CARBON_FOOTPRINT_REDUCTION','Carbon Footprint Reduction','AIR','specialization','EDUCATION','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.AIR.EDUCATION.CONSUMPTION.ARVR_KNOWLEDGE_TRANSFER','AR/VR Knowledge Transfer','AIR','specialization','EDUCATION','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),

 ('WEM.LAND.OUTCOME.HEALTH_PEOPLE','Health & Wellness — People','LAND','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Health & Wellness People"}'::jsonb),
 ('WEM.LAND.OUTCOME.HEALTH_WATERWAYS','Health & Wellness — Waterways','LAND','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Health & Wellness Waterways"}'::jsonb),
 ('WEM.LAND.OUTCOME.HEALTH_LAND_ANIMALS','Health & Wellness — Land & Animals','LAND','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Health & Wellness Land & Animals"}'::jsonb),
 ('WEM.LAND.ENERGY.DISTRIBUTED.BIO_ELECTRO_MAGNETIC','Bio-Electro-Magnetic','LAND','specialization','ENERGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.ENERGY.STORAGE.GREEN_ENERGY_SOLUTION','Green Energy Solution','LAND','specialization','ENERGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.ENERGY.CONSUMPTION.WASTE','Waste','LAND','specialization','ENERGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.TECHNOLOGY.DISTRIBUTED.BANKING_FUND_STRUCTURE','Banking & Fund Structure','LAND','specialization','TECHNOLOGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.TECHNOLOGY.STORAGE.MERCANTILE_EXCHANGE','Mercantile Exchange','LAND','specialization','TECHNOLOGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Merchantile Exchange","normalization_note":"spelling normalized"}'::jsonb),
 ('WEM.LAND.TECHNOLOGY.CONSUMPTION.ECO_FRIENDLY_INDUSTRIES','Eco-Friendly Industries & Community Organizations','LAND','specialization','TECHNOLOGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.EDUCATION.DISTRIBUTED.LAND_MANAGEMENT','Land Management','LAND','specialization','EDUCATION','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.EDUCATION.STORAGE.ORGANIC_GROWTH','Organic Growth Techniques','LAND','specialization','EDUCATION','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.LAND.EDUCATION.CONSUMPTION.KNOWLEDGE_TRANSFER','Knowledge Transfer','LAND','specialization','EDUCATION','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),

 ('WEM.SEA.OUTCOME.ORGANIC_HEALTH','Organic Health','SEA','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.OUTCOME.GLOBAL_WARMING','Global Warming','SEA','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.OUTCOME.CLEAN_WATER_RECOVERY','Clean Water Recovery','SEA','domain_outcome',null,null,'user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.ENERGY.DISTRIBUTED.YTTRIUM_HYDRO','Yttrium Hydro','SEA','specialization','ENERGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"YTTRIUM HYDRO"}'::jsonb),
 ('WEM.SEA.ENERGY.STORAGE.HYDRO_ELECTRIC_INNOVATIONS','Hydro Electric Innovations','SEA','specialization','ENERGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.ENERGY.CONSUMPTION.SEA_LIFE_RESTORATION','Sea Life Restoration','SEA','specialization','ENERGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.TECHNOLOGY.DISTRIBUTED.ACOUSTIC_INNOVATIONS','Acoustic Innovations','SEA','specialization','TECHNOLOGY','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.TECHNOLOGY.STORAGE.NATURAL_NITROGEN_RESTORATION','Natural Nitrogen Restorations','SEA','specialization','TECHNOLOGY','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.TECHNOLOGY.CONSUMPTION.EXISTING_TECH','NASA & Other Existing Technologies','SEA','specialization','TECHNOLOGY','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"NASA & other Existing Techs","governance_note":"conceptual reference only; no NASA relationship asserted"}'::jsonb),
 ('WEM.SEA.EDUCATION.DISTRIBUTED.ECO_TOURISM','Eco-Tourism et al.','SEA','specialization','EDUCATION','DISTRIBUTED','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{"original_label":"Eco-Tourism et. Al"}'::jsonb),
 ('WEM.SEA.EDUCATION.STORAGE.OCEANOGRAPHY','Oceanography','SEA','specialization','EDUCATION','STORAGE','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb),
 ('WEM.SEA.EDUCATION.CONSUMPTION.MARINE_SCIENCE_AWARENESS','Marine Science Awareness','SEA','specialization','EDUCATION','CONSUMPTION','user-supplied Wealth·Eco Matrix','conversation:file_00000000dd0081f59135a18777b13448','{}'::jsonb)
on conflict (canonical_code) do update set
  name=excluded.name,
  domain_code=excluded.domain_code,
  node_type=excluded.node_type,
  enablement_layer=excluded.enablement_layer,
  flow_role=excluded.flow_role,
  source_reference=excluded.source_reference,
  provenance=excluded.provenance,
  updated_at=now();

create or replace view ecology.smart_specialization_matrix as
select
  d.domain_code,
  d.name as domain_name,
  n.canonical_code,
  n.name as node_name,
  n.node_type,
  n.enablement_layer,
  n.flow_role,
  n.conceptual_status,
  n.verification_status,
  n.source_reference,
  n.evidence_reference,
  n.provenance
from ecology.smart_specialization_domains d
join ecology.smart_specialization_nodes n on n.domain_code=d.domain_code;

