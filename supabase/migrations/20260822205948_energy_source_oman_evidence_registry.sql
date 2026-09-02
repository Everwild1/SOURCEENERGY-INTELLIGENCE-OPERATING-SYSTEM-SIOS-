create table if not exists iotf.organization_evidence (
 id uuid primary key default gen_random_uuid(),
 wim_organization_id uuid not null references wim.organizations(id) on delete cascade,
 evidence_code text not null,
 evidence_class text not null check (evidence_class in ('CORPORATE_REGISTRATION','OPERATIONAL_ACTIVATION','TREASURY_COMMERCIAL','GOVERNMENT_CERTIFICATE','BANKING','OTHER')),
 title text not null,
 source_system text not null,
 source_reference text not null,
 evidence_status text not null default 'DOCUMENTATION_RECEIVED' check (evidence_status in ('DOCUMENTATION_RECEIVED','REVIEWED','VERIFIED','REJECTED','SUPERSEDED')),
 authority_level text not null default 'INTERNAL' check (authority_level in ('INTERNAL','THIRD_PARTY','GOVERNMENT','BANK')),
 claims jsonb not null default '{}'::jsonb,
 verification_notes text,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(wim_organization_id,evidence_code)
);
alter table iotf.organization_evidence enable row level security;
revoke all on iotf.organization_evidence from public,anon,authenticated;
grant select,insert,update,delete on iotf.organization_evidence to service_role;
create index if not exists iotf_org_evidence_org_idx on iotf.organization_evidence(wim_organization_id,evidence_status,evidence_class);

insert into iotf.organization_evidence(wim_organization_id,evidence_code,evidence_class,title,source_system,source_reference,evidence_status,authority_level,claims,verification_notes,metadata)
select o.id,x.code,x.class,x.title,'DROPBOX',x.ref,'REVIEWED','INTERNAL',x.claims,x.notes,jsonb_build_object('review_scope','document content only','independent_authority_verification',false)
from wim.organizations o
cross join (values
 ('ESB-OM-CORP-PLAN-20250903','CORPORATE_REGISTRATION','Oman residency activation and business banking setup plan','/המקור/SOURCEENERGY FUND/SEG B&T/Energy Source Business - OMAN/Step-by-Step Guidance Plan to complete the full residency activation and business banking setup for Energy Source Business and Dahlia Harrison in Oman_.pdf',jsonb_build_object('cr_number','1608781','occi_membership','848191','occi_grade','Fourth','tax_card','38079777','tin','2230589','office_lease','stated prepaid','bank_presentation_letter','stated prepared'), 'Internal plan states these corporate identifiers and completion statuses; underlying Omani certificates not yet independently reviewed.'),
 ('ESB-OM-PAYMENT-20250903','OPERATIONAL_ACTIVATION','Energy Source Business Payment Confirmation','/המקור/SOURCEENERGY FUND/SEG B&T/Energy Source Business - OMAN/Energy Source Business Payment_Confirmation_.pdf',jsonb_build_object('amount_usd',13000,'purpose','residency activation','payment_state','allocated and ready for release'), 'Document supports allocation/readiness statement, not proof of completed payment or receipt.'),
 ('ESB-OM-TREASURY-20250528','TREASURY_COMMERCIAL','Vault Treasury Transfer Authorization Memo','/המקור/SOURCEENERGY FUND/SEG B&T/Energy Source Business - OMAN/Vault_Treasury_Transfer_Authorization_Memo_EnergySourceBusiness.pdf',jsonb_build_object('cr_number','1608781','authorized_amount_omr',200000,'approx_usd',520000,'transfer_date','to be confirmed'), 'Internal authorization memo; does not prove bank transfer, receipt, regulatory capital acceptance, or bank account activation.')
) x(code,class,title,ref,claims,notes)
where lower(o.legal_name)='energy source business' and o.jurisdiction_code='OM'
on conflict(wim_organization_id,evidence_code) do update set claims=excluded.claims,verification_notes=excluded.verification_notes,metadata=excluded.metadata,reviewed_at=now();

update iotf.organization_evidence set reviewed_at=coalesce(reviewed_at,now()) where wim_organization_id=(select id from wim.organizations where lower(legal_name)='energy source business' and jurisdiction_code='OM') and evidence_status='REVIEWED';

update wim.organizations set provenance=provenance || jsonb_build_object('evidence_state','DOCUMENTATION_RECEIVED_REVIEW_REQUIRED','dropbox_evidence_reviewed',true,'government_certificate_verification',false,'corporate_identifiers_claimed',jsonb_build_object('cr_number','1608781','occi_membership','848191','tax_card','38079777','tin','2230589')) where lower(legal_name)='energy source business' and jurisdiction_code='OM';

update iotf.counterparty_profiles set provenance=provenance || jsonb_build_object('evidence_state','DOCUMENTATION_RECEIVED_REVIEW_REQUIRED','organizational_verification','PENDING_GOVERNMENT_SOURCE_DOCUMENTS') where wim_organization_id=(select id from wim.organizations where lower(legal_name)='energy source business' and jurisdiction_code='OM');

create or replace view iotf.organization_evidence_readiness with(security_invoker=true) as
select o.id as organization_id,o.legal_name,o.jurisdiction_code,o.verification_status,o.economic_status,count(e.id) as evidence_records,count(e.id) filter(where e.evidence_status in ('REVIEWED','VERIFIED')) as reviewed_records,count(e.id) filter(where e.authority_level in ('GOVERNMENT','BANK') and e.evidence_status='VERIFIED') as authoritative_verified_records,
 case when count(e.id) filter(where e.authority_level in ('GOVERNMENT','BANK') and e.evidence_status='VERIFIED')>0 then 'AUTHORITATIVE_EVIDENCE_VERIFIED' when count(e.id)>0 then 'DOCUMENTATION_RECEIVED_REVIEW_REQUIRED' else 'NO_EVIDENCE' end as evidence_readiness
from wim.organizations o left join iotf.organization_evidence e on e.wim_organization_id=o.id
group by o.id,o.legal_name,o.jurisdiction_code,o.verification_status,o.economic_status;
revoke all on iotf.organization_evidence_readiness from public,anon,authenticated;
grant select on iotf.organization_evidence_readiness to service_role;
