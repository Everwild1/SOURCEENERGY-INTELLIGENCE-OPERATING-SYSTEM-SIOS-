create table if not exists iotf.execution_evidence (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id),
  allocation_id uuid references iotf.capacity_allocations(id),
  transaction_request_id uuid references iotf.transaction_requests(id),
  rgl_shipment_id uuid references rgl.shipments(id),
  rgl_delivery_evidence_id uuid references rgl.delivery_evidence(id),
  evidence_class text not null check (evidence_class in ('BANKING','LEGAL','COMMERCIAL','LOGISTICS','DELIVERY','SETTLEMENT','OTHER')),
  evidence_type text not null,
  evidence_reference text not null,
  verification_status text not null default 'PENDING' check (verification_status in ('PENDING','IN_REVIEW','VERIFIED','REJECTED','SUPERSEDED')),
  authority text,
  checksum text,
  metadata jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
alter table iotf.execution_evidence enable row level security;

create index if not exists iotf_execution_evidence_instrument_idx on iotf.execution_evidence(instrument_id);
create index if not exists iotf_execution_evidence_allocation_idx on iotf.execution_evidence(allocation_id);
create index if not exists iotf_execution_evidence_txreq_idx on iotf.execution_evidence(transaction_request_id);
create index if not exists iotf_execution_evidence_shipment_idx on iotf.execution_evidence(rgl_shipment_id);
create index if not exists iotf_execution_evidence_delivery_idx on iotf.execution_evidence(rgl_delivery_evidence_id);

create table if not exists iotf.governance_decision_evidence (
  id uuid primary key default gen_random_uuid(),
  governance_gate_id uuid not null references iotf.governance_gates(id),
  execution_evidence_id uuid not null references iotf.execution_evidence(id),
  evidence_role text not null default 'SUPPORTING' check (evidence_role in ('REQUIRED','SUPPORTING','CONTRARY','SUPERSEDING')),
  created_at timestamptz not null default now(),
  unique (governance_gate_id, execution_evidence_id)
);
alter table iotf.governance_decision_evidence enable row level security;
create index if not exists iotf_governance_decision_evidence_gate_idx on iotf.governance_decision_evidence(governance_gate_id);
create index if not exists iotf_governance_decision_evidence_evidence_idx on iotf.governance_decision_evidence(execution_evidence_id);

create table if not exists iotf.settlement_events (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id),
  allocation_id uuid not null references iotf.capacity_allocations(id),
  transaction_request_id uuid references iotf.transaction_requests(id),
  settlement_status text not null default 'PENDING' check (settlement_status in ('PENDING','IN_REVIEW','PASSED','SETTLED','REVERSED','FAILED')),
  amount numeric not null check (amount > 0),
  currency char(3) not null,
  settlement_reference text not null,
  settlement_evidence_id uuid references iotf.execution_evidence(id),
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (settlement_reference)
);
alter table iotf.settlement_events enable row level security;
create index if not exists iotf_settlement_events_instrument_idx on iotf.settlement_events(instrument_id);
create index if not exists iotf_settlement_events_allocation_idx on iotf.settlement_events(allocation_id);
create index if not exists iotf_settlement_events_txreq_idx on iotf.settlement_events(transaction_request_id);
create index if not exists iotf_settlement_events_evidence_idx on iotf.settlement_events(settlement_evidence_id);

alter table iotf.capacity_allocations drop constraint if exists capacity_allocations_allocation_status_check;
alter table iotf.capacity_allocations add constraint capacity_allocations_allocation_status_check
  check (allocation_status in ('REQUESTED','ELIGIBILITY_REVIEW','APPROVED','RESERVED','COMMITTED','UTILIZED','SETTLED','RELEASED','REJECTED','CANCELLED'));

create or replace function iotf.enforce_allocation_execution_gates()
returns trigger
language plpgsql
security invoker
set search_path = iotf, pg_temp
as $$
declare
  g4_passed boolean;
  g5_passed boolean;
  verified_settlement boolean;
begin
  if new.allocation_status = 'UTILIZED' and old.allocation_status is distinct from 'UTILIZED' then
    select exists (
      select 1 from iotf.governance_gates g
      where g.instrument_id = new.instrument_id
        and (g.allocation_id = new.id or g.allocation_id is null)
        and g.gate_code = 'G4_BANKING_LEGAL'
        and g.gate_status = 'PASSED'
    ) into g4_passed;
    if not g4_passed then
      raise exception 'G4_BANKING_LEGAL must be PASSED before allocation can become UTILIZED';
    end if;
  end if;

  if new.allocation_status = 'SETTLED' and old.allocation_status is distinct from 'SETTLED' then
    select exists (
      select 1 from iotf.governance_gates g
      where g.instrument_id = new.instrument_id
        and (g.allocation_id = new.id or g.allocation_id is null)
        and g.gate_code = 'G5_SETTLEMENT'
        and g.gate_status = 'PASSED'
    ) into g5_passed;

    select exists (
      select 1
      from iotf.settlement_events s
      join iotf.execution_evidence e on e.id = s.settlement_evidence_id
      where s.allocation_id = new.id
        and s.settlement_status = 'SETTLED'
        and e.verification_status = 'VERIFIED'
        and e.evidence_class = 'SETTLEMENT'
    ) into verified_settlement;

    if not g5_passed or not verified_settlement then
      raise exception 'G5_SETTLEMENT PASSED and verified settlement evidence are required before allocation can become SETTLED';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_iotf_allocation_execution_gates on iotf.capacity_allocations;
create trigger trg_iotf_allocation_execution_gates
before update of allocation_status on iotf.capacity_allocations
for each row execute function iotf.enforce_allocation_execution_gates();

create or replace function iotf.enforce_realized_liquidity_gate()
returns trigger
language plpgsql
security invoker
set search_path = iotf, pg_temp
as $$
declare
  gate_passed boolean;
  evidence_ok boolean;
begin
  if new.event_type = 'LIQUIDITY_REALIZED' then
    if new.allocation_id is null then
      raise exception 'LIQUIDITY_REALIZED requires allocation_id';
    end if;

    select exists (
      select 1 from iotf.governance_gates g
      where g.instrument_id = new.instrument_id
        and (g.allocation_id = new.allocation_id or g.allocation_id is null)
        and g.gate_code = 'G5_SETTLEMENT'
        and g.gate_status = 'PASSED'
    ) into gate_passed;

    select exists (
      select 1
      from iotf.settlement_events s
      join iotf.execution_evidence e on e.id = s.settlement_evidence_id
      where s.allocation_id = new.allocation_id
        and s.settlement_status = 'SETTLED'
        and e.verification_status = 'VERIFIED'
        and e.evidence_class = 'SETTLEMENT'
    ) into evidence_ok;

    if not gate_passed or not evidence_ok then
      raise exception 'G5_SETTLEMENT PASSED and verified settlement evidence are required before LIQUIDITY_REALIZED';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_iotf_realized_liquidity_gate on iotf.capacity_ledger;
create trigger trg_iotf_realized_liquidity_gate
before insert or update of event_type, allocation_id on iotf.capacity_ledger
for each row execute function iotf.enforce_realized_liquidity_gate();

create index if not exists iotf_transaction_requests_wim_transaction_idx on iotf.transaction_requests(wim_transaction_id);

create or replace view iotf.executive_capacity_summary
with (security_invoker = true)
as
select
  i.id as instrument_id,
  i.instrument_code,
  i.face_currency,
  i.face_amount,
  i.recognition_status,
  i.evidence_status,
  i.deployable_cash,
  i.realized_liquidity,
  coalesce(sum(case when a.allocation_status in ('RESERVED','COMMITTED','UTILIZED','SETTLED') then coalesce(a.approved_amount,0) else 0 end),0) as allocated_capacity,
  coalesce(sum(case when a.allocation_status = 'COMMITTED' then coalesce(a.approved_amount,0) else 0 end),0) as committed_capacity,
  coalesce(sum(case when a.allocation_status = 'UTILIZED' then coalesce(a.approved_amount,0) else 0 end),0) as utilized_capacity,
  coalesce(sum(case when a.allocation_status = 'SETTLED' then coalesce(a.approved_amount,0) else 0 end),0) as settled_capacity,
  i.face_amount - coalesce(sum(case when a.allocation_status in ('RESERVED','COMMITTED','UTILIZED','SETTLED') then coalesce(a.approved_amount,0) else 0 end),0) as remaining_face_capacity
from iotf.instruments i
left join iotf.capacity_allocations a on a.instrument_id = i.id
group by i.id, i.instrument_code, i.face_currency, i.face_amount, i.recognition_status, i.evidence_status, i.deployable_cash, i.realized_liquidity;

create or replace view iotf.executive_gate_readiness
with (security_invoker = true)
as
select
  g.instrument_id,
  g.allocation_id,
  g.gate_code,
  g.gate_status,
  g.decision_reference,
  g.decided_at,
  count(gde.execution_evidence_id) filter (where ee.verification_status = 'VERIFIED') as verified_evidence_count,
  count(gde.execution_evidence_id) as linked_evidence_count
from iotf.governance_gates g
left join iotf.governance_decision_evidence gde on gde.governance_gate_id = g.id
left join iotf.execution_evidence ee on ee.id = gde.execution_evidence_id
group by g.id, g.instrument_id, g.allocation_id, g.gate_code, g.gate_status, g.decision_reference, g.decided_at;

create or replace view iotf.executive_transaction_pipeline
with (security_invoker = true)
as
select
  tr.id as transaction_request_id,
  tr.request_code,
  tr.instrument_id,
  tr.wim_transaction_id,
  tr.buyer_organization_id,
  tr.seller_organization_id,
  tr.commodity_id,
  tr.requested_amount,
  tr.currency,
  tr.origination_status,
  tr.composite_score,
  a.id as allocation_id,
  a.allocation_code,
  a.approved_amount,
  a.allocation_status,
  a.rgl_shipment_id,
  s.status as shipment_status,
  s.shipment_reference
from iotf.transaction_requests tr
left join iotf.capacity_allocations a on a.transaction_request_id = tr.id
left join rgl.shipments s on s.id = a.rgl_shipment_id;

