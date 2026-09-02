create table if not exists sourceenergy_one.governance_bootstrap_control (
  bootstrap_id text primary key,
  phase text not null check (phase in ('WAITING_FOR_AUTH_USER','IDENTITY_BINDING','ASSURANCE_VERIFICATION','CONTEXT_ISSUANCE','AUTHORITY_ISSUANCE','COMPLETE','BLOCKED')),
  status text not null check (status in ('PENDING','READY','BLOCKED','COMPLETE')),
  required_actor_assurance text not null default 'strong_verified' check (required_actor_assurance in ('verified','strong_verified')),
  required_context_assurance text not null default 'institutional' check (required_context_assurance = 'institutional'),
  required_authorities jsonb not null default '["VIEW_ASSIGNMENT","MANAGE_ASSIGNMENT","GRANT_AUTHORITY","EXECUTE_GOVERNED_ACTION"]'::jsonb,
  auth_user_id uuid references auth.users(id) on delete restrict,
  actor_identity_id uuid references sourceenergy_one.actor_identities(id) on delete restrict,
  access_context_id uuid references sourceenergy_one.access_contexts(id) on delete restrict,
  control_assignment_id uuid references public.sourcecube_assignments(id) on delete restrict,
  evidence_ref text,
  blocker_reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table sourceenergy_one.governance_bootstrap_control is
'Fail-closed bootstrap ledger for the first SourceCube governance actor. A bootstrap row records readiness only; it never verifies identity or grants authority by itself.';

alter table sourceenergy_one.governance_bootstrap_control enable row level security;

create policy governance_bootstrap_service_role_all
on sourceenergy_one.governance_bootstrap_control
for all
to service_role
using (true)
with check (true);

revoke all on sourceenergy_one.governance_bootstrap_control from anon, authenticated;
grant all on sourceenergy_one.governance_bootstrap_control to service_role;

insert into public.sourcecube_assignments (
  assignment_code,
  source_cube_id,
  object_type,
  object_ref,
  mandate,
  assignment_state,
  restrictions,
  metadata
)
select
  'SCA-SC01-CONTROL-PLANE-001',
  sc.id,
  'ECOSYSTEM_CONTROL_PLANE',
  'SOURCEENERGY_ECOSYSTEM_CONTROL_PLANE',
  'Govern the SourceEnergy SourceCube control-plane assignment, evidence, authorization, delegation and execution boundaries. This assignment is administrative/governance infrastructure and does not itself create legal, financial, regulatory, governmental, custody or execution authority.',
  'EVIDENCE_REQUIRED',
  jsonb_build_object(
    'execution_authority','SEPARATE_VERIFIED_GRANT_REQUIRED',
    'financial_authority','NOT_CONFERRED',
    'institutional_authority','NOT_CONFERRED',
    'creator_status','DOES_NOT_BYPASS_AUTHORIZATION',
    'bootstrap_mode','FAIL_CLOSED'
  ),
  jsonb_build_object(
    'bootstrap_control','SE1-SC-BOOTSTRAP-001',
    'authority_model','VIEW_MANAGE_GRANT_EXECUTE_SEPARATED',
    'source','SourceEnergy One governance bootstrap'
  )
from public.source_cubes sc
where sc.cube_code = 'SC-01'
on conflict (assignment_code) do update
set mandate = excluded.mandate,
    assignment_state = excluded.assignment_state,
    restrictions = excluded.restrictions,
    metadata = excluded.metadata,
    updated_at = now();

insert into sourceenergy_one.governance_bootstrap_control (
  bootstrap_id,
  phase,
  status,
  control_assignment_id,
  blocker_reason,
  notes
)
select
  'SE1-SC-BOOTSTRAP-001',
  case when exists (select 1 from auth.users) then 'IDENTITY_BINDING' else 'WAITING_FOR_AUTH_USER' end,
  case when exists (select 1 from auth.users) then 'READY' else 'BLOCKED' end,
  a.id,
  case when exists (select 1 from auth.users) then null else 'No Supabase Auth user exists. A verified governance actor cannot be bound or granted SourceCube authority until an authenticated identity exists.' end,
  'Required progression: authenticated user -> governed actor identity verification -> institutional access context -> evidence-backed SourceCube authority issuance. No bootstrap step may infer authority solely from creator, administrator, or ownership claims.'
from public.sourcecube_assignments a
where a.assignment_code = 'SCA-SC01-CONTROL-PLANE-001'
on conflict (bootstrap_id) do update
set phase = excluded.phase,
    status = excluded.status,
    control_assignment_id = excluded.control_assignment_id,
    blocker_reason = excluded.blocker_reason,
    notes = excluded.notes,
    updated_at = now();
