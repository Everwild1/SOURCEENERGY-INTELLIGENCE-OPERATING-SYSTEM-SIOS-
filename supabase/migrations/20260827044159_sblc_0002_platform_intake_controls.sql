create table if not exists iotf.private_platform_intake_requirements (
 id uuid primary key default gen_random_uuid(), instrument_id uuid not null references iotf.instruments(id) on delete cascade,
 item_code text not null, category text not null, required_item text not null, minimum_acceptance text not null,
 status text not null default 'AWAITING_COUNTERPARTY' check(status in ('AWAITING_COUNTERPARTY','RECEIVED','UNDER_REVIEW','ACCEPTED','REJECTED','NOT_APPLICABLE')),
 blocking boolean not null default true, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(instrument_id,item_code)
);
alter table iotf.private_platform_intake_requirements enable row level security; revoke all on iotf.private_platform_intake_requirements from public,anon,authenticated; grant select,insert,update,delete on iotf.private_platform_intake_requirements to service_role;

insert into iotf.private_platform_intake_requirements(instrument_id,item_code,category,required_item,minimum_acceptance,blocking,metadata)
select i.id,x.code,x.cat,x.item,x.accept,true,jsonb_build_object('instrument_stage','NON_OPERATIVE_DRAFT') from iotf.instruments i cross join (values
('INTAKE-LEGAL-ENTITY','COUNTERPARTY','Platform legal entity name, registration number, jurisdiction and registered address','Sufficient authoritative evidence to identify and diligence the contracting platform entity.'),
('INTAKE-REGULATORY','COUNTERPARTY','Regulatory/licensing status and applicable regulator where the activity requires authorization','Status independently verifiable or documented legal basis for non-regulated role.'),
('INTAKE-BANK','BANKING','Receiving/custodian bank identity, BIC and bank contact channel','Bank identity independently verifiable; acceptance must ultimately be confirmed bank-to-bank.'),
('INTAKE-STRUCTURE','TRANSACTION','Exact proposed structure: transfer, collateral assignment, discounting, secured lending or other defined mechanism','Written structure that can be tested against instrument terms and legal review.'),
('INTAKE-ALLOCATION','TRANSACTION','Requested face-value allocation and proposed advance/LTV if applicable','Defined amount not exceeding available face capacity; no representation as cash.'),
('INTAKE-FEES','ECONOMICS','Complete fee schedule, timing, payees and refundability','No undisclosed fees; upfront fees require enhanced review and cannot establish instrument validity.'),
('INTAKE-RETURNS','ECONOMICS','Return/yield claims, distribution waterfall and source of returns','Commercially defined and legally reviewable; extraordinary or guaranteed-return claims trigger escalation.'),
('INTAKE-PRIOR-CLOSINGS','DILIGENCE','Evidence of comparable completed transactions and independently contactable counterparties where available','Evidence treated as diligence support only, not substitute for bank confirmation.'),
('INTAKE-COUNSEL','LEGAL','Platform counsel identity and transaction legal documentation','Counsel and governing documents available for transaction-specific review.'),
('INTAKE-CUSTODY','SETTLEMENT','Custody/control mechanics, settlement account structure and proceeds-flow diagram','Mechanics must be verified before commitment or recognition of liquidity.'),
('INTAKE-ISSUER-CONSENT','INSTRUMENT','Process for obtaining issuing-bank consent where proposed whole/partial transfer requires it','Written issuer consent required before transfer-based submission may advance.'),
('INTAKE-SWIFT','INSTRUMENT','Exact requested SWIFT message/process and bank-to-bank verification workflow','Must not rely on applicant-side composed message or registry UETR as proof of transmission.')
) x(code,cat,item,accept) where i.external_reference='SBLC-20260820-0002-11'
on conflict(instrument_id,item_code) do nothing;

create or replace view iotf.private_platform_intake_summary with(security_invoker=true) as
select i.instrument_code,count(r.id) as intake_items,count(r.id) filter(where r.blocking and r.status not in ('ACCEPTED','NOT_APPLICABLE')) as unresolved_intake_items,
 case when count(r.id) filter(where r.blocking and r.status not in ('ACCEPTED','NOT_APPLICABLE'))=0 then 'INTAKE_COMPLETE' else 'AWAITING_PLATFORM' end as intake_state
from iotf.instruments i join iotf.private_platform_intake_requirements r on r.instrument_id=i.id where i.external_reference='SBLC-20260820-0002-11' group by i.id;
revoke all on iotf.private_platform_intake_summary from public,anon,authenticated; grant select on iotf.private_platform_intake_summary to service_role;
