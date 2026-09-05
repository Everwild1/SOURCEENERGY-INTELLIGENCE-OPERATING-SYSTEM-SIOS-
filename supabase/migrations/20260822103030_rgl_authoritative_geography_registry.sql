create table if not exists rgl.geography_registry (
 id uuid primary key default gen_random_uuid(), country_name text not null, iso_alpha2 text not null, iso_alpha3 text not null, un_m49 text,
 un_region text, un_subregion text, rgl_region_code text not null references rgl.strategic_regions(code),
 market_scope text not null default 'strategic' check(market_scope in ('operating','strategic','global')),
 source_authority text not null default 'UN M49', source_reference text, status text not null default 'active',
 created_at timestamptz not null default now(), unique(iso_alpha2)
);
alter table rgl.geography_registry enable row level security;

insert into rgl.geography_registry(country_name,iso_alpha2,iso_alpha3,un_m49,un_region,un_subregion,rgl_region_code,market_scope,source_reference) values
('United States of America','US','USA','840','Americas','Northern America','NAM','operating','UN M49'),('Canada','CA','CAN','124','Americas','Northern America','NAM','operating','UN M49'),('Mexico','MX','MEX','484','Americas','Central America','NAM','operating','UN M49'),
('Jamaica','JM','JAM','388','Americas','Caribbean','CARIB','operating','UN M49'),('Dominican Republic','DO','DOM','214','Americas','Caribbean','CARIB','operating','UN M49'),('Saint Lucia','LC','LCA','662','Americas','Caribbean','CARIB','operating','UN M49'),
('Bahamas','BS','BHS','044','Americas','Caribbean','CARIB','strategic','UN M49'),('Barbados','BB','BRB','052','Americas','Caribbean','CARIB','strategic','UN M49'),('Trinidad and Tobago','TT','TTO','780','Americas','Caribbean','CARIB','strategic','UN M49'),('Haiti','HT','HTI','332','Americas','Caribbean','CARIB','strategic','UN M49'),('Grenada','GD','GRD','308','Americas','Caribbean','CARIB','strategic','UN M49'),('Antigua and Barbuda','AG','ATG','028','Americas','Caribbean','CARIB','strategic','UN M49'),('Dominica','DM','DMA','212','Americas','Caribbean','CARIB','strategic','UN M49'),('Saint Vincent and the Grenadines','VC','VCT','670','Americas','Caribbean','CARIB','strategic','UN M49'),('Saint Kitts and Nevis','KN','KNA','659','Americas','Caribbean','CARIB','strategic','UN M49'),
('Nigeria','NG','NGA','566','Africa','Western Africa','AFR-W','strategic','UN M49'),('Ghana','GH','GHA','288','Africa','Western Africa','AFR-W','strategic','UN M49'),('Senegal','SN','SEN','686','Africa','Western Africa','AFR-W','strategic','UN M49'),('Cote d''Ivoire','CI','CIV','384','Africa','Western Africa','AFR-W','strategic','UN M49'),('Liberia','LR','LBR','430','Africa','Western Africa','AFR-W','strategic','UN M49'),('Sierra Leone','SL','SLE','694','Africa','Western Africa','AFR-W','strategic','UN M49'),
('Kenya','KE','KEN','404','Africa','Eastern Africa','AFR-E','strategic','UN M49'),('Ethiopia','ET','ETH','231','Africa','Eastern Africa','AFR-E','strategic','UN M49'),('United Republic of Tanzania','TZ','TZA','834','Africa','Eastern Africa','AFR-E','strategic','UN M49'),('Rwanda','RW','RWA','646','Africa','Eastern Africa','AFR-E','strategic','UN M49'),('Uganda','UG','UGA','800','Africa','Eastern Africa','AFR-E','strategic','UN M49'),
('Cameroon','CM','CMR','120','Africa','Middle Africa','AFR-C','strategic','UN M49'),('Democratic Republic of the Congo','CD','COD','180','Africa','Middle Africa','AFR-C','strategic','UN M49'),('Angola','AO','AGO','024','Africa','Middle Africa','AFR-C','strategic','UN M49'),
('South Africa','ZA','ZAF','710','Africa','Southern Africa','AFR-S','strategic','UN M49'),('Botswana','BW','BWA','072','Africa','Southern Africa','AFR-S','strategic','UN M49'),('Namibia','NA','NAM','516','Africa','Southern Africa','AFR-S','strategic','UN M49'),
('Egypt','EG','EGY','818','Africa','Northern Africa','AFR-N','strategic','UN M49'),('Morocco','MA','MAR','504','Africa','Northern Africa','AFR-N','strategic','UN M49'),('Algeria','DZ','DZA','012','Africa','Northern Africa','AFR-N','strategic','UN M49'),('Tunisia','TN','TUN','788','Africa','Northern Africa','AFR-N','strategic','UN M49')
on conflict(iso_alpha2) do update set country_name=excluded.country_name,iso_alpha3=excluded.iso_alpha3,un_m49=excluded.un_m49,un_region=excluded.un_region,un_subregion=excluded.un_subregion,rgl_region_code=excluded.rgl_region_code,market_scope=excluded.market_scope,source_reference=excluded.source_reference;

create table if not exists rgl.logistics_indicator_observations (
 id uuid primary key default gen_random_uuid(), geography_id uuid not null references rgl.geography_registry(id) on delete cascade,
 indicator_code text not null, indicator_name text not null, observation_year integer, value numeric, unit text,
 source_authority text not null, source_reference text, methodology_version text, retrieved_at timestamptz not null default now(),
 provenance jsonb not null default '{}'::jsonb, unique(geography_id,indicator_code,observation_year,source_authority)
);
alter table rgl.logistics_indicator_observations enable row level security;

create table if not exists rgl.infrastructure_nodes (
 id uuid primary key default gen_random_uuid(), geography_id uuid not null references rgl.geography_registry(id),
 name text not null, node_type text not null check(node_type in ('seaport','airport','inland_port','rail_terminal','border_crossing','warehouse_zone','logistics_park')),
 unlocode text, iata_code text, icao_code text, latitude numeric, longitude numeric,
 verification_status text not null default 'pending' check(verification_status in ('pending','verified','rejected')),
 source_authority text, source_reference text, status text not null default 'candidate', created_at timestamptz not null default now()
);
alter table rgl.infrastructure_nodes enable row level security;

revoke all on rgl.geography_registry,rgl.logistics_indicator_observations,rgl.infrastructure_nodes from anon,authenticated;
