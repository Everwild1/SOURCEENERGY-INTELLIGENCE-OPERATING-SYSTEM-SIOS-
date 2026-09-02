create table if not exists workforce_ecology.identity_verification_evidence (
  evidence_id uuid primary key default gen_random_uuid(),
  calculation_version text not null,
  principal_type text not null check (principal_type in ('organization','operating_unit','team')),
  principal_reference text not null,
  evidence_type text not null,
  evidence_reference text not null,
  evidence_state text not null default 'submitted' check (evidence_state in ('submitted','accepted','rejected','superseded')),
  reviewed_by_reference text,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  unique(calculation_version,principal_type,principal_reference,evidence_type,evidence_reference)
);
alter table workforce_ecology.identity_verification_evidence enable row level security;
revoke all on workforce_ecology.identity_verification_evidence from public,anon,authenticated;
grant select,insert,update,delete on workforce_ecology.identity_verification_evidence to service_role;

insert into workforce_ecology.identity_verification_evidence
(calculation_version,principal_type,principal_reference,evidence_type,evidence_reference,evidence_state,review_note)
values
('WEI-1.0','operating_unit','SETC-OID-d7844bb5046fa9ddbb262291c5048651','public_program_page','https://sourceenergyglobal.org/center-of-excellence/working-warriors-network/','submitted','Public SourceEnergy page supports existence and Center of Excellence placement; independent institutional verification remains required.'),
('WEI-1.0','organization','SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d','setc_registry_record','public.setc_organizations:SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d','submitted','Canonical SETC record exists but remains PENDING_VERIFICATION.')
on conflict do nothing;

create or replace view workforce_ecology.sios_wei_identity_verification_queue
with (security_invoker=true) as
select pim.mapping_id,pim.calculation_version,pim.principal_type,pim.principal_reference,pim.operating_unit_id,pim.mapping_role,pim.status as mapping_status,
       count(ive.evidence_id) filter (where ive.evidence_state='submitted') as submitted_evidence,
       count(ive.evidence_id) filter (where ive.evidence_state='accepted') as accepted_evidence,
       max(ive.created_at) as latest_evidence_at
from workforce_ecology.pilot_identity_mappings pim
left join workforce_ecology.identity_verification_evidence ive
  on ive.calculation_version=pim.calculation_version
 and ive.principal_type=pim.principal_type
 and ive.principal_reference=pim.principal_reference
where pim.calculation_version='WEI-1.0'
group by pim.mapping_id,pim.calculation_version,pim.principal_type,pim.principal_reference,pim.operating_unit_id,pim.mapping_role,pim.status;
revoke all on workforce_ecology.sios_wei_identity_verification_queue from public,anon,authenticated;
grant select on workforce_ecology.sios_wei_identity_verification_queue to service_role;
