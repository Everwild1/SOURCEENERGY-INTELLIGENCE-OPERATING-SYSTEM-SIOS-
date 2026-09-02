create table if not exists iotf.private_platform_candidates (
 id uuid primary key default gen_random_uuid(), instrument_id uuid not null references iotf.instruments(id) on delete cascade,
 platform_name text, legal_entity_name text, jurisdiction text, regulated_status text, receiving_bank_name text, custodian_bank_name text,
 proposed_allocation_amount numeric(20,2) check(proposed_allocation_amount is null or proposed_allocation_amount>0), proposed_structure text,
 diligence_status text not null default 'NOT_STARTED' check(diligence_status in ('NOT_STARTED','INTAKE','IN_REVIEW','PASSED','FAILED','WITHDRAWN')),
 submission_authorized boolean not null default false, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table iotf.private_platform_candidates enable row level security; revoke all on iotf.private_platform_candidates from public,anon,authenticated; grant select,insert,update,delete on iotf.private_platform_candidates to service_role;

create table if not exists iotf.private_platform_diligence_items (
 id uuid primary key default gen_random_uuid(), candidate_id uuid not null references iotf.private_platform_candidates(id) on delete cascade,
 item_code text not null, item_text text not null, status text not null default 'OUTSTANDING' check(status in ('OUTSTANDING','RECEIVED','VERIFIED','FAILED','NOT_APPLICABLE')),
 blocking boolean not null default true, evidence_reference text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(candidate_id,item_code)
);
alter table iotf.private_platform_diligence_items enable row level security; revoke all on iotf.private_platform_diligence_items from public,anon,authenticated; grant select,insert,update,delete on iotf.private_platform_diligence_items to service_role;

create table if not exists iotf.private_platform_allocations (
 id uuid primary key default gen_random_uuid(), instrument_id uuid not null references iotf.instruments(id) on delete cascade, candidate_id uuid references iotf.private_platform_candidates(id) on delete restrict,
 allocation_code text not null unique, allocation_amount numeric(20,2) not null check(allocation_amount>0), allocation_status text not null default 'PROPOSED' check(allocation_status in ('PROPOSED','RESERVED_G4_PENDING','APPROVED','COMMITTED','RELEASED','CANCELLED')),
 deployable_cash numeric(20,2) not null default 0 check(deployable_cash>=0), realized_liquidity numeric(20,2) not null default 0 check(realized_liquidity>=0),
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table iotf.private_platform_allocations enable row level security; revoke all on iotf.private_platform_allocations from public,anon,authenticated; grant select,insert,update,delete on iotf.private_platform_allocations to service_role;

create or replace function iotf.enforce_private_platform_allocation() returns trigger language plpgsql security invoker set search_path=iotf,pg_temp as $$
declare face numeric; blockers integer; auth boolean;
begin
 select face_amount into face from iotf.instruments where id=new.instrument_id;
 if new.allocation_amount > face then raise exception 'Allocation exceeds instrument face amount'; end if;
 if new.allocation_status in ('APPROVED','COMMITTED') then
   if new.candidate_id is null then raise exception 'Approved/committed allocation requires platform candidate'; end if;
   select count(*) into blockers from iotf.private_platform_diligence_items where candidate_id=new.candidate_id and blocking and status not in ('VERIFIED','NOT_APPLICABLE');
   select submission_authorized into auth from iotf.private_platform_candidates where id=new.candidate_id;
   if blockers>0 or not coalesce(auth,false) then raise exception 'Platform allocation cannot be approved/committed while diligence blockers remain or submission is unauthorized'; end if;
 end if;
 if new.deployable_cash>0 or new.realized_liquidity>0 then raise exception 'Draft-stage platform allocation cannot recognize deployable cash or realized liquidity'; end if;
 return new;
end; $$;
drop trigger if exists trg_private_platform_allocation on iotf.private_platform_allocations; create trigger trg_private_platform_allocation before insert or update on iotf.private_platform_allocations for each row execute function iotf.enforce_private_platform_allocation();

create or replace view iotf.private_platform_capacity_summary with(security_invoker=true) as
select i.instrument_code,i.face_amount,
 coalesce(sum(a.allocation_amount) filter(where a.allocation_status in ('RESERVED_G4_PENDING','APPROVED','COMMITTED')),0) as reserved_or_committed,
 i.face_amount-coalesce(sum(a.allocation_amount) filter(where a.allocation_status in ('RESERVED_G4_PENDING','APPROVED','COMMITTED')),0) as unallocated_face_capacity,
 i.deployable_cash,i.realized_liquidity
from iotf.instruments i left join iotf.private_platform_allocations a on a.instrument_id=i.id where i.external_reference='SBLC-20260820-0002-11' group by i.id;
revoke all on iotf.private_platform_capacity_summary from public,anon,authenticated; grant select on iotf.private_platform_capacity_summary to service_role;
