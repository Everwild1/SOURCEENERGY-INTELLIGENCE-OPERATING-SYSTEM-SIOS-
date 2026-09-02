insert into wim.organizations(legal_name,display_name,organization_type,verification_status,economic_status,provenance)
select x.legal_name,x.display_name,x.organization_type,'pending','active',jsonb_build_object('source','IOTF buyer activation','activation_basis','user authorized','verification_scope','pending authoritative organization evidence')
from (values
 ('SourceEnergy Foundation','SourceEnergy Foundation','foundation'),
 ('SourceEnergy Global','SourceEnergy Global','commercial_procurement'),
 ('Diaspora Health Group','Diaspora Health Group','healthcare_group')
) as x(legal_name,display_name,organization_type)
where not exists (select 1 from wim.organizations o where lower(o.legal_name)=lower(x.legal_name));

insert into iotf.counterparty_profiles(wim_organization_id,role_codes,eligibility_status,risk_tier,provenance)
select o.id,
 case
  when lower(o.legal_name)='sourceenergy foundation' then array['BUYER','INSTRUMENT_BENEFICIARY','STRATEGIC_PRINCIPAL']::text[]
  when lower(o.legal_name)='sourceenergy global' then array['BUYER','PRIMARY_PROCUREMENT_ORIGINATOR','TRADE_ORIGINATOR']::text[]
  when lower(o.legal_name)='diaspora health group' then array['BUYER','HEALTHCARE_PROCUREMENT']::text[]
  when lower(o.legal_name)='robert global logistics llc' then array['BUYER','LOGISTICS_PROVIDER','PROCUREMENT_SUPPORT']::text[]
 end,
 'PENDING',null,jsonb_build_object('buyer_capability','ACTIVE','instrument_use_authority',false,'g2_g3_g4_required',true)
from wim.organizations o
where lower(o.legal_name) in ('sourceenergy foundation','sourceenergy global','diaspora health group','robert global logistics llc')
on conflict (wim_organization_id) do update set
 role_codes=(select array_agg(distinct v) from unnest(iotf.counterparty_profiles.role_codes || excluded.role_codes) v),
 provenance=iotf.counterparty_profiles.provenance || excluded.provenance,
 updated_at=now();
