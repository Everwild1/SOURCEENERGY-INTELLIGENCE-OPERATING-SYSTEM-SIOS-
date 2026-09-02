alter table workforce_ecology.policy_versions
  add column if not exists approval_scope text not null default 'pre_production'
    check (approval_scope in ('pre_production','limited_pilot','controlled_scale','unrestricted_production'));

create table if not exists workforce_ecology.governance_reviewers (
  reviewer_role_id uuid primary key default gen_random_uuid(),
  calculation_version text not null,
  role_code text not null,
  role_name text not null,
  authority_scope text not null,
  required_for_pilot boolean not null default true,
  required_for_scale boolean not null default true,
  assigned_principal_reference text,
  assigned_user_id uuid,
  status text not null default 'unassigned' check (status in ('unassigned','active','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (calculation_version, role_code),
  check ((status='active' and assigned_principal_reference is not null) or status <> 'active')
);

create table if not exists workforce_ecology.pilot_authorizations (
  pilot_authorization_id uuid primary key default gen_random_uuid(),
  authorization_code text not null unique,
  calculation_version text not null,
  authorization_scope text not null default 'limited_pilot' check (authorization_scope='limited_pilot'),
  status text not null default 'approved_pending_assignments' check (status in ('approved_pending_assignments','active','suspended','completed','revoked')),
  directive_reference text not null,
  authorized_at timestamptz not null default now(),
  operating_unit_id text,
  team_id text,
  conditions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists workforce_ecology.pilot_identity_mappings (
  mapping_id uuid primary key default gen_random_uuid(),
  calculation_version text not null,
  principal_type text not null check (principal_type in ('organization','operating_unit','team','reviewer','data_steward')),
  principal_reference text not null,
  operating_unit_id text,
  team_id text,
  mapping_role text not null,
  status text not null default 'pending' check (status in ('pending','verified','retired')),
  verified_at timestamptz,
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique (calculation_version, principal_type, principal_reference, mapping_role)
);

alter table workforce_ecology.production_gate
  add column if not exists pilot_authorization_reference text;

alter table workforce_ecology.governance_reviewers enable row level security;
alter table workforce_ecology.pilot_authorizations enable row level security;
alter table workforce_ecology.pilot_identity_mappings enable row level security;

revoke all on workforce_ecology.governance_reviewers from public, anon, authenticated;
revoke all on workforce_ecology.pilot_authorizations from public, anon, authenticated;
revoke all on workforce_ecology.pilot_identity_mappings from public, anon, authenticated;
grant select,insert,update,delete on workforce_ecology.governance_reviewers to service_role;
grant select,insert,update,delete on workforce_ecology.pilot_authorizations to service_role;
grant select,insert,update,delete on workforce_ecology.pilot_identity_mappings to service_role;

insert into workforce_ecology.governance_reviewers
(calculation_version,role_code,role_name,authority_scope,required_for_pilot,required_for_scale)
values
('WEI-1.0','EXECUTIVE_SPONSOR','Executive Sponsor','Institutional sponsorship and pilot accountability',true,true),
('WEI-1.0','WORKFORCE_GOVERNANCE_REVIEWER','Workforce Governance Reviewer','Workforce policy, intervention and fairness review',true,true),
('WEI-1.0','PRIVACY_HUMAN_REVIEWER','Privacy & Human Review','Privacy, dignity, aggregation and human-authority controls',true,true),
('WEI-1.0','TECHNICAL_DATA_STEWARD','Technical Data Steward','Metric lineage, data quality and calculation integrity',true,true),
('WEI-1.0','PILOT_OPERATING_UNIT_OWNER','Pilot Operating Unit Owner','Pilot operating-unit accountability and local review',true,true)
on conflict (calculation_version,role_code) do nothing;

insert into workforce_ecology.pilot_authorizations
(authorization_code,calculation_version,status,directive_reference,conditions)
values
('WEI-1.0-LIMITED-PILOT-2026-08-28','WEI-1.0','approved_pending_assignments','USER_DIRECTIVE_2026-08-28',
 '{"no_real_workforce_data_until_assignments_complete":true,"named_reviewers_required":true,"verified_identity_mapping_required":true,"no_autonomous_personnel_action":true,"limited_pilot_only":true,"fairness_privacy_signal_review_required_before_scale":true}'::jsonb)
on conflict (authorization_code) do nothing;

update workforce_ecology.policy_versions
set status='approved',
    approval_scope='limited_pilot',
    approved_by_reference='WEI-1.0-LIMITED-PILOT-2026-08-28',
    approval_date=current_date
where version_name='WEI-1.0';

update workforce_ecology.production_gate
set pilot_authorization_reference='WEI-1.0-LIMITED-PILOT-2026-08-28',
    pilot_scope=jsonb_build_object('authorization_scope','limited_pilot','activation_state','pending_reviewer_and_identity_assignments'),
    updated_at=now()
where calculation_version='WEI-1.0';

create or replace view workforce_ecology.sios_wei_pilot_readiness
with (security_invoker=true)
as
select
  pv.version_name as calculation_version,
  pv.status as policy_status,
  pv.approval_scope,
  pa.authorization_code,
  pa.status as pilot_authorization_status,
  pg.status as production_gate_status,
  count(gr.reviewer_role_id) filter (where gr.required_for_pilot) as required_reviewer_roles,
  count(gr.reviewer_role_id) filter (where gr.required_for_pilot and gr.status='active' and gr.assigned_principal_reference is not null) as assigned_reviewer_roles,
  (select count(*) from workforce_ecology.pilot_identity_mappings pim where pim.calculation_version=pv.version_name and pim.status='verified') as verified_identity_mappings,
  (pv.status='approved'
   and pv.approval_scope='limited_pilot'
   and pa.status in ('approved_pending_assignments','active')
   and count(gr.reviewer_role_id) filter (where gr.required_for_pilot) > 0
   and count(gr.reviewer_role_id) filter (where gr.required_for_pilot and gr.status='active' and gr.assigned_principal_reference is not null)
       = count(gr.reviewer_role_id) filter (where gr.required_for_pilot)
   and (select count(*) from workforce_ecology.pilot_identity_mappings pim where pim.calculation_version=pv.version_name and pim.status='verified') > 0
  ) as pilot_ready,
  pa.conditions
from workforce_ecology.policy_versions pv
join workforce_ecology.pilot_authorizations pa on pa.calculation_version=pv.version_name
left join workforce_ecology.production_gate pg on pg.calculation_version=pv.version_name
left join workforce_ecology.governance_reviewers gr on gr.calculation_version=pv.version_name
where pv.version_name='WEI-1.0'
group by pv.version_name,pv.status,pv.approval_scope,pa.authorization_code,pa.status,pg.status,pa.conditions;

revoke all on workforce_ecology.sios_wei_pilot_readiness from public, anon, authenticated;
grant select on workforce_ecology.sios_wei_pilot_readiness to service_role;
