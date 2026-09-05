create table if not exists iotf.organization_verification_requirements (
 id uuid primary key default gen_random_uuid(),
 wim_organization_id uuid not null references wim.organizations(id) on delete cascade,
 requirement_code text not null,
 requirement_class text not null check (requirement_class in ('GOVERNMENT_REGISTRATION','CHAMBER_MEMBERSHIP','TAX','BANKING','OTHER')),
 required_evidence text not null,
 status text not null default 'OUTSTANDING' check (status in ('OUTSTANDING','SEARCHED_NOT_FOUND','RECEIVED','VERIFIED','WAIVED','SUPERSEDED')),
 last_search_at timestamptz,
 search_sources text[] not null default '{}',
 notes text,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(wim_organization_id,requirement_code)
);
alter table iotf.organization_verification_requirements enable row level security;
revoke all on iotf.organization_verification_requirements from public,anon,authenticated;
grant select,insert,update,delete on iotf.organization_verification_requirements to service_role;

insert into iotf.organization_verification_requirements(wim_organization_id,requirement_code,requirement_class,required_evidence,status,last_search_at,search_sources,notes,metadata)
select o.id,x.code,x.class,x.req,'SEARCHED_NOT_FOUND',now(),array['GOOGLE_DRIVE','DROPBOX']::text[],x.notes,x.metadata
from wim.organizations o
cross join (values
 ('ESB-OM-REQ-CR-CURRENT','GOVERNMENT_REGISTRATION','Current MoCIIP / Invest Easy Commercial Registration extract for CR 1608781','No separately stored government-issued current CR extract located in targeted Drive/Dropbox searches.',jsonb_build_object('cr_number','1608781')),
 ('ESB-OM-REQ-OCCI-CURRENT','CHAMBER_MEMBERSHIP','Current or renewed Oman Chamber of Commerce & Industry membership record for OCCI 848191','No renewed/current OCCI record located. Existing internal addendum states expiry 2026-05-27.',jsonb_build_object('occi_number','848191','known_expiry','2026-05-27')),
 ('ESB-OM-REQ-TAX-CURRENT','TAX','Oman Tax Authority registration certificate or current extract for Tax Card 38079777 / TIN 2230589','No separately stored authority-issued tax certificate located in targeted Drive/Dropbox searches.',jsonb_build_object('tax_card','38079777','tin','2230589')),
 ('ESB-OM-REQ-BANK-ACCOUNT','BANKING','Bank-issued corporate account confirmation or statement evidencing active Energy Source Business Oman account','No bank-issued account confirmation located. Existing records are onboarding/presentation or internal activation materials only.',jsonb_build_object('sensitive_details_should_be_redacted',true))
) x(code,class,req,notes,metadata)
where lower(o.legal_name)='energy source business' and o.jurisdiction_code='OM'
on conflict(wim_organization_id,requirement_code) do update set status='SEARCHED_NOT_FOUND',last_search_at=now(),search_sources=excluded.search_sources,notes=excluded.notes,metadata=iotf.organization_verification_requirements.metadata||excluded.metadata,updated_at=now();

create or replace view iotf.organization_verification_gap_summary with(security_invoker=true) as
select o.id as organization_id,o.legal_name,o.jurisdiction_code,o.verification_status,
 count(r.id) as total_requirements,
 count(r.id) filter(where r.status='VERIFIED') as verified_requirements,
 count(r.id) filter(where r.status='SEARCHED_NOT_FOUND') as searched_not_found,
 jsonb_object_agg(r.requirement_code,r.status order by r.requirement_code) as requirement_statuses
from wim.organizations o
join iotf.organization_verification_requirements r on r.wim_organization_id=o.id
group by o.id,o.legal_name,o.jurisdiction_code,o.verification_status;
revoke all on iotf.organization_verification_gap_summary from public,anon,authenticated;
grant select on iotf.organization_verification_gap_summary to service_role;
