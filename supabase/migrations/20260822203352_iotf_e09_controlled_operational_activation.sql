create table if not exists iotf.activation_cases (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id) on delete restrict,
  activation_code text not null unique,
  activation_status text not null default 'PREPARATION' check (activation_status in ('PREPARATION','EVIDENCE_INTAKE','UNDER_REVIEW','ELIGIBLE','ACTIVE','SUSPENDED','CLOSED','REJECTED')),
  current_gate text not null default 'G1_EVIDENCE' check (current_gate in ('G1_EVIDENCE','G2_ELIGIBILITY','G3_COMMERCIAL','G4_BANKING_LEGAL','G5_SETTLEMENT','COMPLETE')),
  activation_owner text,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table iotf.activation_cases enable row level security;
revoke all on iotf.activation_cases from public, anon, authenticated;
grant select, insert, update, delete on iotf.activation_cases to service_role;
create index if not exists iotf_activation_cases_instrument_idx on iotf.activation_cases(instrument_id);
create index if not exists iotf_activation_cases_status_idx on iotf.activation_cases(activation_status, current_gate);

create table if not exists iotf.gate_decision_log (
  id bigint generated always as identity primary key,
  instrument_id uuid not null references iotf.instruments(id) on delete restrict,
  allocation_id uuid references iotf.capacity_allocations(id) on delete restrict,
  gate_code text not null check (gate_code in ('G1_EVIDENCE','G2_ELIGIBILITY','G3_COMMERCIAL','G4_BANKING_LEGAL','G5_SETTLEMENT')),
  prior_status text,
  new_status text not null check (new_status in ('PENDING','IN_REVIEW','PASSED','FAILED','WAIVED','SUPERSEDED')),
  decision_reference text,
  decision_basis jsonb not null default '{}'::jsonb,
  decided_by text,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table iotf.gate_decision_log enable row level security;
revoke all on iotf.gate_decision_log from public, anon, authenticated;
grant select, insert on iotf.gate_decision_log to service_role;
create index if not exists iotf_gate_decision_log_instrument_idx on iotf.gate_decision_log(instrument_id, gate_code, decided_at desc);
create index if not exists iotf_gate_decision_log_allocation_idx on iotf.gate_decision_log(allocation_id) where allocation_id is not null;

create or replace function iotf.enforce_gate_pass_requirements()
returns trigger
language plpgsql
security invoker
set search_path = iotf, pg_temp
as $$
declare
  evidence_ok boolean := false;
  banking_ok boolean := false;
  legal_ok boolean := false;
  settlement_ok boolean := false;
begin
  if new.gate_status = 'PASSED' and old.gate_status is distinct from 'PASSED' then
    if new.gate_code = 'G1_EVIDENCE' then
      select exists (
        select 1 from iotf.instrument_evidence ie
        where ie.instrument_id = new.instrument_id
          and ie.evidence_status in ('REVIEWED','ACCEPTED')
      ) into evidence_ok;
      if not evidence_ok then
        raise exception 'G1_EVIDENCE cannot PASS without reviewed or accepted instrument evidence';
      end if;
    elsif new.gate_code = 'G4_BANKING_LEGAL' then
      select exists (
        select 1
        from iotf.governance_decision_evidence gde
        join iotf.execution_evidence ee on ee.id = gde.execution_evidence_id
        where gde.governance_gate_id = new.id
          and ee.evidence_class = 'BANKING'
          and ee.verification_status = 'VERIFIED'
      ) into banking_ok;
      select exists (
        select 1
        from iotf.governance_decision_evidence gde
        join iotf.execution_evidence ee on ee.id = gde.execution_evidence_id
        where gde.governance_gate_id = new.id
          and ee.evidence_class = 'LEGAL'
          and ee.verification_status = 'VERIFIED'
      ) into legal_ok;
      if not banking_ok or not legal_ok then
        raise exception 'G4_BANKING_LEGAL cannot PASS without verified BANKING and LEGAL evidence linked to the gate';
      end if;
    elsif new.gate_code = 'G5_SETTLEMENT' then
      select exists (
        select 1
        from iotf.governance_decision_evidence gde
        join iotf.execution_evidence ee on ee.id = gde.execution_evidence_id
        where gde.governance_gate_id = new.id
          and ee.evidence_class = 'SETTLEMENT'
          and ee.verification_status = 'VERIFIED'
      ) into settlement_ok;
      if not settlement_ok then
        raise exception 'G5_SETTLEMENT cannot PASS without verified SETTLEMENT evidence linked to the gate';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_iotf_enforce_gate_pass_requirements on iotf.governance_gates;
create trigger trg_iotf_enforce_gate_pass_requirements
before update of gate_status on iotf.governance_gates
for each row execute function iotf.enforce_gate_pass_requirements();

create or replace function iotf.log_gate_decision()
returns trigger
language plpgsql
security invoker
set search_path = iotf, pg_temp
as $$
begin
  if new.gate_status is distinct from old.gate_status then
    insert into iotf.gate_decision_log(
      instrument_id, allocation_id, gate_code, prior_status, new_status,
      decision_reference, decision_basis, decided_at
    ) values (
      new.instrument_id, new.allocation_id, new.gate_code, old.gate_status, new.gate_status,
      new.decision_reference, coalesce(new.decision_metadata,'{}'::jsonb), coalesce(new.decided_at,now())
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_iotf_log_gate_decision on iotf.governance_gates;
create trigger trg_iotf_log_gate_decision
after update of gate_status on iotf.governance_gates
for each row execute function iotf.log_gate_decision();

create or replace function iotf.advance_activation_case(p_activation_id uuid)
returns text
language plpgsql
security invoker
set search_path = iotf, pg_temp
as $$
declare
  c iotf.activation_cases;
  target_gate text;
  target_status text;
begin
  select * into c from iotf.activation_cases where id = p_activation_id for update;
  if not found then raise exception 'activation case not found'; end if;

  if c.current_gate = 'G1_EVIDENCE' then
    if not exists (select 1 from iotf.governance_gates g where g.instrument_id=c.instrument_id and g.allocation_id is null and g.gate_code='G1_EVIDENCE' and g.gate_status='PASSED') then
      raise exception 'G1_EVIDENCE has not passed';
    end if;
    target_gate := 'G2_ELIGIBILITY'; target_status := 'UNDER_REVIEW';
  elsif c.current_gate = 'G2_ELIGIBILITY' then
    if not exists (select 1 from iotf.governance_gates g where g.instrument_id=c.instrument_id and g.allocation_id is null and g.gate_code='G2_ELIGIBILITY' and g.gate_status='PASSED') then
      raise exception 'G2_ELIGIBILITY has not passed';
    end if;
    target_gate := 'G3_COMMERCIAL'; target_status := 'UNDER_REVIEW';
  elsif c.current_gate = 'G3_COMMERCIAL' then
    if not exists (select 1 from iotf.governance_gates g where g.instrument_id=c.instrument_id and g.allocation_id is null and g.gate_code='G3_COMMERCIAL' and g.gate_status='PASSED') then
      raise exception 'G3_COMMERCIAL has not passed';
    end if;
    target_gate := 'G4_BANKING_LEGAL'; target_status := 'UNDER_REVIEW';
  elsif c.current_gate = 'G4_BANKING_LEGAL' then
    if not exists (select 1 from iotf.governance_gates g where g.instrument_id=c.instrument_id and g.allocation_id is null and g.gate_code='G4_BANKING_LEGAL' and g.gate_status='PASSED') then
      raise exception 'G4_BANKING_LEGAL has not passed';
    end if;
    target_gate := 'G5_SETTLEMENT'; target_status := 'ACTIVE';
  elsif c.current_gate = 'G5_SETTLEMENT' then
    if not exists (select 1 from iotf.governance_gates g where g.instrument_id=c.instrument_id and g.allocation_id is null and g.gate_code='G5_SETTLEMENT' and g.gate_status='PASSED') then
      raise exception 'G5_SETTLEMENT has not passed';
    end if;
    target_gate := 'COMPLETE'; target_status := 'CLOSED';
  else
    return c.current_gate;
  end if;

  update iotf.activation_cases
     set current_gate=target_gate, activation_status=target_status, updated_at=now()
   where id=c.id;
  return target_gate;
end;
$$;
revoke all on function iotf.advance_activation_case(uuid) from public, anon, authenticated;
grant execute on function iotf.advance_activation_case(uuid) to service_role;

create or replace view iotf.activation_readiness
with (security_invoker = true)
as
select
  ac.id as activation_id,
  ac.activation_code,
  ac.instrument_id,
  ac.activation_status,
  ac.current_gate,
  i.instrument_code,
  i.recognition_status,
  i.evidence_status,
  i.face_currency,
  i.face_amount,
  i.deployable_cash,
  i.realized_liquidity,
  bool_and(g.gate_status='PASSED') filter (where g.gate_code in ('G1_EVIDENCE','G2_ELIGIBILITY','G3_COMMERCIAL','G4_BANKING_LEGAL','G5_SETTLEMENT')) as all_gates_passed,
  jsonb_object_agg(g.gate_code,g.gate_status order by g.gate_code) filter (where g.allocation_id is null) as gate_statuses
from iotf.activation_cases ac
join iotf.instruments i on i.id=ac.instrument_id
left join iotf.governance_gates g on g.instrument_id=ac.instrument_id and g.allocation_id is null
group by ac.id, ac.activation_code, ac.instrument_id, ac.activation_status, ac.current_gate,
         i.instrument_code, i.recognition_status, i.evidence_status, i.face_currency, i.face_amount,
         i.deployable_cash, i.realized_liquidity;

insert into iotf.activation_cases(instrument_id,activation_code,activation_status,current_gate,metadata)
select id,'SE-ACT-SBLC-20260820-0001-14','EVIDENCE_INTAKE','G1_EVIDENCE',jsonb_build_object('basis','conditional recognition; evidence pending')
from iotf.instruments
where external_reference='SBLC-20260820-0001-14'
on conflict (activation_code) do nothing;
