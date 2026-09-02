insert into wim.organizations(legal_name,display_name,organization_type,jurisdiction_code,verification_status,economic_status,provenance)
select 'Energy Source Business','Energy Source Business — Oman','energy_trading_distribution','OM','pending','active',jsonb_build_object('source','IOTF Oman activation','activation_basis','user authorized','regional_mandate','Oman/GCC with global trade capability','verification_scope','pending authoritative organization evidence')
where not exists(select 1 from wim.organizations where lower(legal_name)='energy source business' and jurisdiction_code='OM');

insert into iotf.counterparty_profiles(wim_organization_id,role_codes,eligibility_status,provenance)
select o.id,array['BUYER','SELLER','PROCUREMENT','ENERGY_TRADE_ORIGINATOR','ENERGY_DISTRIBUTOR','OMAN_GCC_HUB']::text[],'PENDING',jsonb_build_object('buyer_capability','ACTIVE','seller_capability','ACTIVE','procurement_capability','ACTIVE','instrument_use_authority',false,'g2_g3_g4_required',true,'regional_mandate','Oman/GCC with global trade capability')
from wim.organizations o where lower(o.legal_name)='energy source business' and o.jurisdiction_code='OM'
on conflict(wim_organization_id) do update set
 role_codes=(select array_agg(distinct v) from unnest(iotf.counterparty_profiles.role_codes || excluded.role_codes) v),
 provenance=iotf.counterparty_profiles.provenance||excluded.provenance,
 updated_at=now();

create table if not exists iotf.energy_operating_mandates(
 id uuid primary key default gen_random_uuid(),
 wim_organization_id uuid not null unique references wim.organizations(id) on delete restrict,
 home_jurisdiction text not null,
 regional_scope text[] not null default '{}',
 buyer_capability boolean not null default true,
 seller_capability boolean not null default true,
 procurement_capability boolean not null default true,
 distribution_capability boolean not null default true,
 instrument_use_authority boolean not null default false,
 g4_required boolean not null default true,
 status text not null default 'ACTIVE' check(status in ('ACTIVE','PENDING','SUSPENDED','INACTIVE')),
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table iotf.energy_operating_mandates enable row level security;
revoke all on iotf.energy_operating_mandates from public,anon,authenticated;
grant select,insert,update,delete on iotf.energy_operating_mandates to service_role;

insert into iotf.energy_operating_mandates(wim_organization_id,home_jurisdiction,regional_scope,metadata)
select id,'OM',array['OMAN','GCC','AFRICA','CARIBBEAN_BASIN','NORTH_AMERICA','GLOBAL']::text[],jsonb_build_object('commercial_role','energy procurement trading distribution and market execution','treasury_role',false,'custody_role',false)
from wim.organizations where lower(legal_name)='energy source business' and jurisdiction_code='OM'
on conflict(wim_organization_id) do update set regional_scope=excluded.regional_scope,metadata=iotf.energy_operating_mandates.metadata||excluded.metadata,updated_at=now();

create table if not exists iotf.energy_commodity_capabilities(
 id uuid primary key default gen_random_uuid(),
 wim_organization_id uuid not null references wim.organizations(id) on delete cascade,
 commodity_id uuid not null references gsc.commodities(id) on delete restrict,
 capability_status text not null default 'CANDIDATE' check(capability_status in ('CANDIDATE','ACTIVE','SUSPENDED','INACTIVE')),
 capability_types text[] not null default array['BUY','SELL','DISTRIBUTE']::text[],
 requires_transaction_eligibility boolean not null default true,
 requires_g4_confirmation boolean not null default true,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(wim_organization_id,commodity_id)
);
alter table iotf.energy_commodity_capabilities enable row level security;
revoke all on iotf.energy_commodity_capabilities from public,anon,authenticated;
grant select,insert,update,delete on iotf.energy_commodity_capabilities to service_role;

insert into iotf.energy_commodity_capabilities(wim_organization_id,commodity_id,capability_status,metadata)
select o.id,g.id,'CANDIDATE',jsonb_build_object('basis','GSC energy commodity catalog','bank_approved_use',false)
from wim.organizations o join gsc.commodities g on g.category='energy_fuel'
where lower(o.legal_name)='energy source business' and o.jurisdiction_code='OM'
on conflict(wim_organization_id,commodity_id) do nothing;

create or replace view iotf.energy_source_oman_control_matrix with(security_invoker=true) as
select o.legal_name,o.display_name,o.jurisdiction_code,o.verification_status,o.economic_status,m.regional_scope,m.buyer_capability,m.seller_capability,m.procurement_capability,m.distribution_capability,m.instrument_use_authority,m.g4_required,m.status,
 (select count(*) from iotf.energy_commodity_capabilities c where c.wim_organization_id=o.id and c.capability_status='CANDIDATE') as candidate_energy_commodities
from wim.organizations o join iotf.energy_operating_mandates m on m.wim_organization_id=o.id
where lower(o.legal_name)='energy source business' and o.jurisdiction_code='OM';
revoke all on iotf.energy_source_oman_control_matrix from public,anon,authenticated;
grant select on iotf.energy_source_oman_control_matrix to service_role;
