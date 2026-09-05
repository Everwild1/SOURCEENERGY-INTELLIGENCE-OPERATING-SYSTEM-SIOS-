create table iotf.counterparty_profiles (
  id uuid primary key default gen_random_uuid(),
  wim_organization_id uuid not null unique references wim.organizations(id) on delete restrict,
  role_codes text[] not null default '{}',
  eligibility_status text not null default 'PENDING' check (eligibility_status in ('PENDING','ELIGIBLE','INELIGIBLE','SUSPENDED')),
  risk_tier text check (risk_tier is null or risk_tier in ('LOW','MODERATE','ELEVATED','HIGH')),
  kyc_reference text,
  sanctions_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table iotf.transaction_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text not null unique,
  instrument_id uuid not null references iotf.instruments(id) on delete restrict,
  wim_transaction_id uuid references wim.transactions(id) on delete restrict,
  buyer_organization_id uuid references wim.organizations(id) on delete restrict,
  seller_organization_id uuid references wim.organizations(id) on delete restrict,
  commodity_id uuid references gsc.commodities(id) on delete restrict,
  requested_amount numeric(20,2) not null check (requested_amount > 0),
  currency char(3) not null,
  goods_description text not null,
  purchase_order_reference text,
  contract_reference text,
  logistics_reference text,
  expected_margin_bps integer,
  expected_settlement_date date,
  origination_status text not null default 'DRAFT' check (origination_status in ('DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','CANCELLED')),
  eligibility_score numeric(5,2),
  commercial_score numeric(5,2),
  strategic_score numeric(5,2),
  composite_score numeric(6,2),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table iotf.capacity_allocations add column transaction_request_id uuid references iotf.transaction_requests(id) on delete restrict;
create unique index iotf_allocations_transaction_request_uidx on iotf.capacity_allocations(transaction_request_id) where transaction_request_id is not null;
create index iotf_counterparty_role_gin on iotf.counterparty_profiles using gin(role_codes);
create index iotf_txreq_instrument_status_idx on iotf.transaction_requests(instrument_id, origination_status);
create index iotf_txreq_buyer_idx on iotf.transaction_requests(buyer_organization_id) where buyer_organization_id is not null;
create index iotf_txreq_seller_idx on iotf.transaction_requests(seller_organization_id) where seller_organization_id is not null;
create index iotf_txreq_commodity_idx on iotf.transaction_requests(commodity_id) where commodity_id is not null;

alter table iotf.counterparty_profiles enable row level security;
alter table iotf.transaction_requests enable row level security;
revoke all on iotf.counterparty_profiles, iotf.transaction_requests from public, anon, authenticated;
grant select, insert, update, delete on iotf.counterparty_profiles, iotf.transaction_requests to service_role;

create trigger iotf_counterparty_profiles_updated_at
before update on iotf.counterparty_profiles
for each row execute function iotf.set_updated_at();

create trigger iotf_transaction_requests_updated_at
before update on iotf.transaction_requests
for each row execute function iotf.set_updated_at();

create or replace function iotf.sync_transaction_request_score()
returns trigger
language plpgsql
set search_path = pg_catalog, iotf
as $$
begin
  new.composite_score := round((coalesce(new.eligibility_score,0)*0.40 + coalesce(new.commercial_score,0)*0.35 + coalesce(new.strategic_score,0)*0.25)::numeric,2);
  return new;
end;
$$;

create trigger iotf_transaction_requests_score
before insert or update of eligibility_score,commercial_score,strategic_score on iotf.transaction_requests
for each row execute function iotf.sync_transaction_request_score();

create or replace function iotf.create_allocation_for_approved_request(p_request_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = pg_catalog, iotf, wim, gsc, rgl
as $$
declare
  r iotf.transaction_requests;
  alloc_id uuid;
  alloc_code text;
begin
  select * into r from iotf.transaction_requests where id = p_request_id;
  if not found then raise exception 'transaction request not found'; end if;
  if r.origination_status <> 'APPROVED' then raise exception 'transaction request must be APPROVED'; end if;

  if exists (
    select 1 from iotf.governance_gates g
    where g.instrument_id = r.instrument_id
      and g.allocation_id is null
      and g.gate_code in ('G1_EVIDENCE','G2_ELIGIBILITY')
      and g.gate_status <> 'PASSED'
  ) then
    raise exception 'instrument evidence and eligibility gates must be PASSED';
  end if;

  alloc_code := 'SE-ICL-' || replace(r.request_code,'SE-TR-','');

  insert into iotf.capacity_allocations(
    allocation_code,instrument_id,transaction_request_id,wim_transaction_id,
    wim_organization_id,gsc_commodity_id,requested_amount,approved_amount,currency,
    allocation_status,purpose,provenance
  ) values (
    alloc_code,r.instrument_id,r.id,r.wim_transaction_id,r.buyer_organization_id,
    r.commodity_id,r.requested_amount,r.requested_amount,r.currency,
    'APPROVED',r.goods_description,jsonb_build_object('source','transaction_request')
  ) returning id into alloc_id;

  insert into iotf.governance_gates(instrument_id,allocation_id,gate_code,gate_status)
  values
    (r.instrument_id,alloc_id,'G3_COMMERCIAL','PASSED'),
    (r.instrument_id,alloc_id,'G4_BANKING_LEGAL','PENDING'),
    (r.instrument_id,alloc_id,'G5_SETTLEMENT','PENDING');

  return alloc_id;
end;
$$;

revoke all on function iotf.create_allocation_for_approved_request(uuid) from public, anon, authenticated;
grant execute on function iotf.create_allocation_for_approved_request(uuid) to service_role;

create or replace function iotf.reserve_allocation(p_allocation_id uuid, p_reference text)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, iotf
as $$
declare
  a iotf.capacity_allocations;
  i iotf.instruments;
  used numeric(20,2);
begin
  select * into a from iotf.capacity_allocations where id = p_allocation_id for update;
  if not found then raise exception 'allocation not found'; end if;
  if a.allocation_status <> 'APPROVED' then raise exception 'allocation must be APPROVED'; end if;
  select * into i from iotf.instruments where id = a.instrument_id for update;
  if i.recognition_status not in ('CONDITIONAL','EVIDENCE_RECEIVED','ELIGIBILITY_ESTABLISHED','ACTIVE_CAPACITY') then raise exception 'instrument status does not permit reservation'; end if;

  select coalesce(sum(case when event_type in ('RESERVED','RESERVATION_RELEASED','COMMITTED','COMMITMENT_RELEASED','UTILIZED','UTILIZATION_REVERSED') then amount*direction else 0 end),0)
    into used from iotf.capacity_ledger where instrument_id = a.instrument_id;
  if used + coalesce(a.approved_amount,a.requested_amount) > i.face_amount then raise exception 'insufficient face capacity'; end if;

  insert into iotf.capacity_ledger(instrument_id,allocation_id,event_type,amount,currency,direction,event_reference,metadata)
  values(a.instrument_id,a.id,'RESERVED',coalesce(a.approved_amount,a.requested_amount),a.currency,1,p_reference,jsonb_build_object('transaction_request_id',a.transaction_request_id));

  update iotf.capacity_allocations set allocation_status='RESERVED' where id=a.id;
end;
$$;

revoke all on function iotf.reserve_allocation(uuid,text) from public, anon, authenticated;
grant execute on function iotf.reserve_allocation(uuid,text) to service_role;

create or replace function iotf.commit_allocation(p_allocation_id uuid, p_reference text)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, iotf
as $$
declare a iotf.capacity_allocations;
begin
  select * into a from iotf.capacity_allocations where id=p_allocation_id for update;
  if not found then raise exception 'allocation not found'; end if;
  if a.allocation_status <> 'RESERVED' then raise exception 'allocation must be RESERVED'; end if;
  if exists (select 1 from iotf.governance_gates where allocation_id=a.id and gate_code='G4_BANKING_LEGAL' and gate_status<>'PASSED') then
    raise exception 'G4_BANKING_LEGAL must be PASSED before commitment';
  end if;
  insert into iotf.capacity_ledger(instrument_id,allocation_id,event_type,amount,currency,direction,event_reference)
  values(a.instrument_id,a.id,'COMMITTED',coalesce(a.approved_amount,a.requested_amount),a.currency,1,p_reference);
  insert into iotf.capacity_ledger(instrument_id,allocation_id,event_type,amount,currency,direction,event_reference)
  values(a.instrument_id,a.id,'RESERVATION_RELEASED',coalesce(a.approved_amount,a.requested_amount),a.currency,-1,p_reference||'-release');
  update iotf.capacity_allocations set allocation_status='COMMITTED' where id=a.id;
end;
$$;

revoke all on function iotf.commit_allocation(uuid,text) from public, anon, authenticated;
grant execute on function iotf.commit_allocation(uuid,text) to service_role;

create view iotf.transaction_pipeline
with (security_invoker=true)
as
select
  tr.id as transaction_request_id,tr.request_code,tr.instrument_id,tr.wim_transaction_id,
  tr.buyer_organization_id,tr.seller_organization_id,tr.commodity_id,tr.requested_amount,tr.currency,
  tr.goods_description,tr.origination_status,tr.composite_score,
  ca.id as allocation_id,ca.allocation_code,ca.allocation_status,
  bg.gate_status as banking_legal_gate,sg.gate_status as settlement_gate
from iotf.transaction_requests tr
left join iotf.capacity_allocations ca on ca.transaction_request_id=tr.id
left join iotf.governance_gates bg on bg.allocation_id=ca.id and bg.gate_code='G4_BANKING_LEGAL'
left join iotf.governance_gates sg on sg.allocation_id=ca.id and sg.gate_code='G5_SETTLEMENT';

revoke all on iotf.transaction_pipeline from public, anon, authenticated;
grant select on iotf.transaction_pipeline to service_role;
