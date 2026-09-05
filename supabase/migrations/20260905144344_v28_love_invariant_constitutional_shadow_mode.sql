-- V28: AGB-7D/L Love invariant shadow-mode constitutional layer.
-- Mirrors the live SourceEnergy command backend deployment.

create table if not exists sourceenergy_one.love_invariant_assessments (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  object_type text not null,
  object_ref uuid not null,
  spirit_gate_assessment_id uuid not null references sourceenergy_one.spirit_gate_assessments(id) on delete restrict,
  invariant_version text not null default 'love-invariant-v1',
  status text not null default 'assessed' check (status in ('assessed','human_confirmed','rejected')),
  basis text not null,
  beneficiary_analysis jsonb not null default '[]'::jsonb,
  harm_analysis jsonb not null default '[]'::jsonb,
  self_interest_analysis jsonb not null default '{}'::jsonb,
  uncertainty jsonb not null default '{}'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  assessed_by_actor_ref text not null,
  consent_scope_id text not null,
  human_reviewed_by_actor_ref text,
  human_reviewed_at timestamptz,
  human_attestation text,
  assessment_hash text not null check (assessment_hash ~ '^[0-9a-f]{64}$'),
  supersedes_assessment_id uuid references sourceenergy_one.love_invariant_assessments(id),
  created_at timestamptz not null default now()
);

create unique index if not exists love_invariant_one_confirmed_per_object
  on sourceenergy_one.love_invariant_assessments(object_type, object_ref, invariant_version)
  where status='human_confirmed';

alter table sourceenergy_one.love_invariant_assessments enable row level security;
drop policy if exists love_invariant_service_role on sourceenergy_one.love_invariant_assessments;
create policy love_invariant_service_role on sourceenergy_one.love_invariant_assessments
  for all to service_role using (true) with check (true);

create or replace function sourceenergy_one.require_love_invariant(p_object_type text,p_object_ref uuid)
returns boolean language plpgsql security definer set search_path to 'sourceenergy_one','pg_temp' as $$
begin
  if not exists(
    select 1
    from sourceenergy_one.love_invariant_assessments l
    join sourceenergy_one.spirit_gate_assessments s on s.id=l.spirit_gate_assessment_id
    where l.object_type=p_object_type
      and l.object_ref=p_object_ref
      and l.invariant_version='love-invariant-v1'
      and l.status='human_confirmed'
      and s.gate_version='spirit-gate-v3'
      and s.status='human_confirmed'
  ) then
    raise exception 'Love invariant v1 not satisfied for % %',p_object_type,p_object_ref;
  end if;
  return true;
end;
$$;

create or replace function sourceenergy_one.require_genesis_constitutional_gate(p_object_type text,p_object_ref uuid)
returns boolean language plpgsql security definer set search_path to 'sourceenergy_one','pg_temp' as $$
begin
  perform sourceenergy_one.require_spirit_gate(p_object_type,p_object_ref);
  perform sourceenergy_one.require_love_invariant(p_object_type,p_object_ref);
  return true;
end;
$$;

create table if not exists wealth_ecology.decision_love_evaluations (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null unique references wealth_ecology.decisions(id) on delete cascade,
  status wealth_ecology.evaluation_status not null default 'PENDING',
  basis text,
  beneficiary_analysis jsonb not null default '[]'::jsonb,
  harm_analysis jsonb not null default '[]'::jsonb,
  self_interest_analysis jsonb not null default '{}'::jsonb,
  uncertainty jsonb not null default '{}'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  evaluated_by text,
  evaluated_at timestamptz,
  human_reviewed_by text,
  human_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table wealth_ecology.decision_love_evaluations enable row level security;
drop policy if exists service_role_full_access_decision_love_evaluations on wealth_ecology.decision_love_evaluations;
create policy service_role_full_access_decision_love_evaluations on wealth_ecology.decision_love_evaluations
  for all to service_role using (true) with check (true);

create or replace function wealth_ecology.evaluate_decision_readiness_v2(p_decision_id uuid)
returns jsonb language plpgsql set search_path to '' as $$
declare
  d7_total int; d7_done int; p4_done int; seci_done int; love_done int; firewall_bad int; failures int;
begin
  select count(*) into d7_total from wnf7.dimension_registry;
  select count(*) into d7_done from wealth_ecology.decision_7d_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
  select count(*) into p4_done from wealth_ecology.decision_4p_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
  select count(*) into seci_done from wealth_ecology.decision_seci_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
  select count(*) into love_done from wealth_ecology.decision_love_evaluations where decision_id=p_decision_id and status='PASS' and human_reviewed_by is not null and human_reviewed_at is not null;
  select count(*) into firewall_bad from wealth_ecology.cross_domain_mappings m
    where m.target_wealth_ecology_object in (select purpose_ref from wealth_ecology.decisions where id=p_decision_id)
      and (m.mechanism_equivalence_status='NOT_ESTABLISHED' or m.review_status<>'APPROVED');
  select count(*) into failures from wealth_ecology.decision_7d_evaluations where decision_id=p_decision_id and status='FAIL';

  return jsonb_build_object(
    'seven_d_complete',d7_total>0 and d7_done=d7_total,
    'love_invariant_complete',love_done=1,
    'four_p_complete',p4_done=4,
    'seci_complete',seci_done=4,
    'scientific_firewall_passed',firewall_bad=0,
    'authorization_ready',d7_total>0 and d7_done=d7_total and love_done=1 and p4_done=4 and seci_done=4 and firewall_bad=0 and failures=0
  );
end;
$$;

alter table wealth_ecology.execution_authorizations
  add column if not exists constitutional_gate_version text,
  add column if not exists constitutional_decision_id uuid references wealth_ecology.decisions(id) on delete restrict;
