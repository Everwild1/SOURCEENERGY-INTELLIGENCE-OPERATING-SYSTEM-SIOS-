create schema if not exists iotf;

revoke all on schema iotf from public, anon, authenticated;
grant usage on schema iotf to service_role;

create table iotf.instruments (
  id uuid primary key default gen_random_uuid(),
  instrument_code text not null unique,
  instrument_type text not null,
  message_type text,
  external_reference text not null unique,
  uetr uuid,
  face_currency char(3) not null,
  face_amount numeric(20,2) not null check (face_amount > 0),
  tenor_days integer check (tenor_days is null or tenor_days > 0),
  stated_purpose text,
  applicant_name text,
  beneficiary_name text not null,
  beneficiary_bank_name text,
  issuing_bank_name text,
  governing_law text,
  issued_at timestamptz,
  recognition_status text not null default 'CONDITIONAL' check (recognition_status in ('CONDITIONAL','EVIDENCE_RECEIVED','ELIGIBILITY_ESTABLISHED','ACTIVE_CAPACITY','SUSPENDED','CLOSED','REJECTED')),
  evidence_status text not null default 'PENDING' check (evidence_status in ('PENDING','PARTIAL','RECEIVED','REVIEWED','SUPERSEDED')),
  deployable_cash numeric(20,2) not null default 0 check (deployable_cash >= 0),
  realized_liquidity numeric(20,2) not null default 0 check (realized_liquidity >= 0),
  source_basis text not null default 'USER_SUPPLIED_DOCUMENT',
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (deployable_cash <= face_amount),
  check (realized_liquidity <= face_amount)
);

create table iotf.instrument_evidence (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id) on delete cascade,
  evidence_type text not null,
  evidence_reference text not null,
  evidence_status text not null default 'RECEIVED' check (evidence_status in ('RECEIVED','REVIEWED','ACCEPTED','REJECTED','SUPERSEDED')),
  source_class text not null default 'USER_SUPPLIED',
  metadata jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (instrument_id, evidence_reference)
);

create table iotf.capacity_allocations (
  id uuid primary key default gen_random_uuid(),
  allocation_code text not null unique,
  instrument_id uuid not null references iotf.instruments(id) on delete restrict,
  wim_transaction_id uuid references wim.transactions(id) on delete restrict,
  wim_organization_id uuid references wim.organizations(id) on delete restrict,
  gsc_commodity_id uuid references gsc.commodities(id) on delete restrict,
  rgl_shipment_id uuid references rgl.shipments(id) on delete restrict,
  requested_amount numeric(20,2) not null check (requested_amount > 0),
  approved_amount numeric(20,2) check (approved_amount is null or approved_amount >= 0),
  currency char(3) not null,
  allocation_status text not null default 'REQUESTED' check (allocation_status in ('REQUESTED','ELIGIBILITY_REVIEW','APPROVED','RESERVED','COMMITTED','UTILIZED','RELEASED','REJECTED','CANCELLED')),
  purpose text,
  expires_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (approved_amount is null or approved_amount <= requested_amount)
);

create table iotf.governance_gates (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id) on delete cascade,
  allocation_id uuid references iotf.capacity_allocations(id) on delete cascade,
  gate_code text not null check (gate_code in ('G1_EVIDENCE','G2_ELIGIBILITY','G3_COMMERCIAL','G4_BANKING_LEGAL','G5_SETTLEMENT')),
  gate_status text not null default 'PENDING' check (gate_status in ('PENDING','IN_REVIEW','PASSED','FAILED','WAIVED','SUPERSEDED')),
  decision_reference text,
  decision_metadata jsonb not null default '{}'::jsonb,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique nulls not distinct (instrument_id, allocation_id, gate_code)
);

create table iotf.capacity_ledger (
  id bigint generated always as identity primary key,
  instrument_id uuid not null references iotf.instruments(id) on delete restrict,
  allocation_id uuid references iotf.capacity_allocations(id) on delete restrict,
  event_type text not null check (event_type in ('FACE_RECOGNIZED','RESERVED','RESERVATION_RELEASED','COMMITTED','COMMITMENT_RELEASED','UTILIZED','UTILIZATION_REVERSED','LIQUIDITY_REALIZED','LIQUIDITY_REVERSED','CLOSED')),
  amount numeric(20,2) not null check (amount > 0),
  currency char(3) not null,
  direction smallint not null check (direction in (-1,1)),
  event_reference text not null,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (instrument_id, event_type, event_reference)
);

create index iotf_evidence_instrument_idx on iotf.instrument_evidence(instrument_id);
create index iotf_allocations_instrument_status_idx on iotf.capacity_allocations(instrument_id, allocation_status);
create index iotf_allocations_wim_transaction_idx on iotf.capacity_allocations(wim_transaction_id) where wim_transaction_id is not null;
create index iotf_allocations_org_idx on iotf.capacity_allocations(wim_organization_id) where wim_organization_id is not null;
create index iotf_allocations_commodity_idx on iotf.capacity_allocations(gsc_commodity_id) where gsc_commodity_id is not null;
create index iotf_allocations_shipment_idx on iotf.capacity_allocations(rgl_shipment_id) where rgl_shipment_id is not null;
create index iotf_gates_allocation_idx on iotf.governance_gates(allocation_id) where allocation_id is not null;
create index iotf_ledger_instrument_time_idx on iotf.capacity_ledger(instrument_id, occurred_at desc);
create index iotf_ledger_allocation_idx on iotf.capacity_ledger(allocation_id) where allocation_id is not null;

alter table iotf.instruments enable row level security;
alter table iotf.instrument_evidence enable row level security;
alter table iotf.capacity_allocations enable row level security;
alter table iotf.governance_gates enable row level security;
alter table iotf.capacity_ledger enable row level security;

revoke all on all tables in schema iotf from public, anon, authenticated;
grant select, insert, update, delete on iotf.instruments, iotf.instrument_evidence, iotf.capacity_allocations, iotf.governance_gates to service_role;
grant select, insert on iotf.capacity_ledger to service_role;
grant usage, select on all sequences in schema iotf to service_role;

create or replace function iotf.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, iotf
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger iotf_instruments_updated_at
before update on iotf.instruments
for each row execute function iotf.set_updated_at();

create trigger iotf_allocations_updated_at
before update on iotf.capacity_allocations
for each row execute function iotf.set_updated_at();

create or replace function iotf.prevent_capacity_ledger_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, iotf
as $$
begin
  raise exception 'iotf.capacity_ledger is append-only';
end;
$$;

create trigger iotf_capacity_ledger_no_update
before update or delete on iotf.capacity_ledger
for each row execute function iotf.prevent_capacity_ledger_mutation();

create view iotf.instrument_capacity_summary
with (security_invoker = true)
as
select
  i.id as instrument_id,
  i.instrument_code,
  i.external_reference,
  i.face_currency,
  i.face_amount,
  i.recognition_status,
  i.evidence_status,
  i.deployable_cash,
  i.realized_liquidity,
  coalesce(sum(case when l.event_type = 'RESERVED' then l.amount * l.direction else 0 end),0)::numeric(20,2) as reserved_capacity,
  coalesce(sum(case when l.event_type in ('COMMITTED','COMMITMENT_RELEASED') then l.amount * l.direction else 0 end),0)::numeric(20,2) as committed_capacity,
  coalesce(sum(case when l.event_type in ('UTILIZED','UTILIZATION_REVERSED') then l.amount * l.direction else 0 end),0)::numeric(20,2) as utilized_capacity,
  (i.face_amount - coalesce(sum(case when l.event_type in ('RESERVED','RESERVATION_RELEASED','COMMITTED','COMMITMENT_RELEASED','UTILIZED','UTILIZATION_REVERSED') then l.amount * l.direction else 0 end),0))::numeric(20,2) as unallocated_conditional_capacity
from iotf.instruments i
left join iotf.capacity_ledger l on l.instrument_id = i.id
group by i.id;

revoke all on iotf.instrument_capacity_summary from public, anon, authenticated;
grant select on iotf.instrument_capacity_summary to service_role;

insert into iotf.instruments (
  instrument_code, instrument_type, message_type, external_reference, uetr,
  face_currency, face_amount, tenor_days, stated_purpose, applicant_name,
  beneficiary_name, beneficiary_bank_name, issuing_bank_name, governing_law,
  issued_at, recognition_status, evidence_status, deployable_cash, realized_liquidity,
  source_basis, provenance
) values (
  'SE-IOTF-SBLC-20260820-0001-14','SBLC','MT760','SBLC-20260820-0001-14',
  '346b0e3d-d80a-4a80-8028-94c124c20e50','USD',153000000.00,365,'GOODS PURCHASE',
  'BLOCKOAK EQUITY LTD, SWITZERLAND','SOURCEENERGY FOUNDATION, US','Truist Bank',
  'UBS Switzerland AG','ENGLISH LAW','2026-08-20T16:04:49.396+00:00',
  'CONDITIONAL','PENDING',0,0,'USER_SUPPLIED_DOCUMENT',
  jsonb_build_object('source_file','SBLC-20260820-0001-14-verbiage.pdf','recognition_basis','CONDITIONAL_EVIDENCE_PENDING','draw_structure_stated','PARTIAL_AND_MULTIPLE_PERMITTED')
);

insert into iotf.instrument_evidence (instrument_id,evidence_type,evidence_reference,evidence_status,source_class,metadata)
select id,'SOURCE_DOCUMENT','SBLC-20260820-0001-14-verbiage.pdf','RECEIVED','USER_SUPPLIED',jsonb_build_object('basis','uploaded_pdf')
from iotf.instruments where external_reference='SBLC-20260820-0001-14';

insert into iotf.capacity_ledger (instrument_id,event_type,amount,currency,direction,event_reference,metadata)
select id,'FACE_RECOGNIZED',153000000.00,'USD',1,'INITIAL_CONDITIONAL_RECOGNITION',jsonb_build_object('recognition_status','CONDITIONAL','deployable_cash',0,'realized_liquidity',0)
from iotf.instruments where external_reference='SBLC-20260820-0001-14';

insert into iotf.governance_gates (instrument_id, gate_code, gate_status)
select i.id, g.gate_code, 'PENDING'
from iotf.instruments i
cross join (values ('G1_EVIDENCE'),('G2_ELIGIBILITY'),('G3_COMMERCIAL'),('G4_BANKING_LEGAL'),('G5_SETTLEMENT')) as g(gate_code)
where i.external_reference='SBLC-20260820-0001-14';
