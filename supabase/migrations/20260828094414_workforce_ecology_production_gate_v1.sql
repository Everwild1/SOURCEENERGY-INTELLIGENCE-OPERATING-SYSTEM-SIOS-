create table if not exists workforce_ecology.production_gate (
  gate_id uuid primary key default gen_random_uuid(),
  gate_code text not null unique,
  calculation_version text not null,
  status text not null check (status in ('blocked','pilot_authorized','production_authorized','suspended')) default 'blocked',
  authorization_reference text,
  authorized_by_reference text,
  authorized_at timestamptz,
  pilot_scope jsonb not null default '{}'::jsonb,
  conditions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table workforce_ecology.production_gate enable row level security;
revoke all on workforce_ecology.production_gate from public, anon, authenticated;
grant select, insert, update, delete on workforce_ecology.production_gate to service_role;

insert into workforce_ecology.production_gate(gate_code,calculation_version,status,conditions)
values('WEI-1.0-PRODUCTION-GATE','WEI-1.0','blocked',jsonb_build_object(
  'policy_must_be_approved',true,
  'production_identity_mapping_required',true,
  'human_reviewers_required',true,
  'limited_pilot_required_before_scale',true,
  'no_autonomous_personnel_action',true
)) on conflict(gate_code) do nothing;

create or replace view workforce_ecology.sios_wei_production_gate
with (security_invoker=true)
as select gate_id,gate_code,calculation_version,status,authorization_reference,
 authorized_by_reference,authorized_at,pilot_scope,conditions,created_at,updated_at
from workforce_ecology.production_gate;
revoke all on workforce_ecology.sios_wei_production_gate from public, anon, authenticated;
grant select on workforce_ecology.sios_wei_production_gate to service_role;
