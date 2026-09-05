create table if not exists iotf.financial_institution_roles (
 id uuid primary key default gen_random_uuid(),
 wim_organization_id uuid not null references wim.organizations(id) on delete restrict,
 role_code text not null,
 role_class text not null check (role_class in ('CAPITALIZATION','TREASURY_TRUST','ADVISORY')),
 mandate text not null,
 authority_level text not null default 'ADVISORY' check (authority_level in ('ADVISORY','STRUCTURING','GOVERNANCE')),
 buyer_capability boolean not null default false,
 instrument_use_authority boolean not null default false,
 unilateral_gate_authority boolean not null default false,
 status text not null default 'ACTIVE' check (status in ('ACTIVE','PENDING','SUSPENDED','INACTIVE')),
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(wim_organization_id,role_code)
);
alter table iotf.financial_institution_roles enable row level security;
revoke all on iotf.financial_institution_roles from public,anon,authenticated;
grant select,insert,update,delete on iotf.financial_institution_roles to service_role;
create index if not exists iotf_financial_roles_org_idx on iotf.financial_institution_roles(wim_organization_id,status);

insert into wim.organizations(legal_name,display_name,organization_type,verification_status,economic_status,provenance)
select x.legal_name,x.display_name,x.organization_type,'pending','active',jsonb_build_object('source','IOTF institutional role activation','activation_basis','user authorized','verification_scope','pending authoritative organization evidence')
from (values
 ('SourceEnergy Capital','SourceEnergy Capital','capitalization_institution'),
 ('SourceEnergy ScrollBank and Covenant Trust','SourceEnergy ScrollBank and Covenant Trust','treasury_trust_governance'),
 ('SourceEnergy Wealth Advisors','SourceEnergy Wealth Advisors','wealth_advisory')
) x(legal_name,display_name,organization_type)
where not exists(select 1 from wim.organizations o where lower(o.legal_name)=lower(x.legal_name));

insert into iotf.counterparty_profiles(wim_organization_id,role_codes,eligibility_status,provenance)
select o.id,
 case lower(o.legal_name)
  when 'sourceenergy capital' then array['CAPITALIZATION_MANAGER','STRUCTURED_FINANCE','FACILITY_ORCHESTRATOR','CAPITAL_ALLOCATION']::text[]
  when 'sourceenergy scrollbank and covenant trust' then array['TREASURY_GOVERNOR','INSTRUMENT_REGISTRY','COVENANT_TRUST','EVIDENCE_CUSTODIAN','SETTLEMENT_GOVERNANCE','CAPACITY_LEDGER_OVERSIGHT']::text[]
  when 'sourceenergy wealth advisors' then array['WEALTH_ADVISOR','CAPITAL_ALLOCATION_ADVISOR','PORTFOLIO_INTELLIGENCE','RISK_ADVISORY','WEALTH_ECOLOGY_ANALYTICS']::text[]
 end,
 'PENDING',jsonb_build_object('buyer_capability','INACTIVE','instrument_use_authority',false,'institutional_role_layer',true)
from wim.organizations o
where lower(o.legal_name) in ('sourceenergy capital','sourceenergy scrollbank and covenant trust','sourceenergy wealth advisors')
on conflict(wim_organization_id) do update set role_codes=excluded.role_codes,provenance=iotf.counterparty_profiles.provenance||excluded.provenance,updated_at=now();

insert into iotf.financial_institution_roles(wim_organization_id,role_code,role_class,mandate,authority_level,buyer_capability,instrument_use_authority,unilateral_gate_authority,metadata)
select o.id,x.role_code,x.role_class,x.mandate,x.authority_level,false,false,false,jsonb_build_object('segregation_of_duties',true,'g4_required',true)
from wim.organizations o
join (values
 ('SourceEnergy Capital','CAPITALIZATION_MANAGER','CAPITALIZATION','Structure capital stacks, facilities, working-capital requirements and transaction capitalization without authenticating instruments or passing banking/legal gates.','STRUCTURING'),
 ('SourceEnergy ScrollBank and Covenant Trust','TREASURY_GOVERNOR','TREASURY_TRUST','Govern instrument registry, treasury controls, evidence custody, capacity-ledger oversight, settlement governance and audit provenance without unilateral authority to authenticate or deploy the instrument.','GOVERNANCE'),
 ('SourceEnergy Wealth Advisors','WEALTH_ADVISOR','ADVISORY','Provide portfolio, risk, capital-allocation and Wealth Ecology analytics; recommendations remain advisory and non-custodial.','ADVISORY')
) x(legal_name,role_code,role_class,mandate,authority_level) on lower(o.legal_name)=lower(x.legal_name)
on conflict(wim_organization_id,role_code) do update set mandate=excluded.mandate,authority_level=excluded.authority_level,metadata=iotf.financial_institution_roles.metadata||excluded.metadata,updated_at=now();

create or replace view iotf.financial_institution_control_matrix with (security_invoker=true) as
select o.legal_name,o.verification_status,o.economic_status,f.role_class,f.role_code,f.authority_level,f.buyer_capability,f.instrument_use_authority,f.unilateral_gate_authority,f.status,f.mandate
from iotf.financial_institution_roles f join wim.organizations o on o.id=f.wim_organization_id;
revoke all on iotf.financial_institution_control_matrix from public,anon,authenticated;
grant select on iotf.financial_institution_control_matrix to service_role;
