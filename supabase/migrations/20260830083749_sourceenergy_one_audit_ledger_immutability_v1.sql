alter table sourceenergy_one.audit_events add column if not exists previous_event_hash text;
alter table sourceenergy_one.audit_events add column if not exists event_hash text;
alter table sourceenergy_one.audit_events add column if not exists chain_version text not null default 'audit-chain-v1';

with ordered as (
  select id,lag(event_hash) over(order by id) as prev_hash from sourceenergy_one.audit_events
), recomputed as (
  select a.id,o.prev_hash,
    encode(extensions.digest(convert_to((jsonb_build_object('id',a.id,'correlation_id',a.correlation_id,'subject_id',a.subject_id,'actor_id',a.actor_id,'event_type',a.event_type,'object_type',a.object_type,'object_ref',a.object_ref,'payload',a.payload,'occurred_at',a.occurred_at,'previous_event_hash',o.prev_hash,'chain_version','audit-chain-v1'))::text,'UTF8'),'sha256'::text),'hex') as h
  from sourceenergy_one.audit_events a join ordered o using(id)
)
update sourceenergy_one.audit_events a set previous_event_hash=r.prev_hash,event_hash=r.h,chain_version='audit-chain-v1' from recomputed r where a.id=r.id and a.event_hash is null;

create or replace function sourceenergy_one.audit_events_before_insert_hash()
returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$
declare prev text; next_id bigint;
begin
  if new.id is null then next_id:=nextval(pg_get_serial_sequence('sourceenergy_one.audit_events','id')); new.id:=next_id; else next_id:=new.id; end if;
  select event_hash into prev from sourceenergy_one.audit_events order by id desc limit 1;
  new.previous_event_hash:=prev;
  new.chain_version:='audit-chain-v1';
  new.event_hash:=encode(extensions.digest(convert_to((jsonb_build_object('id',new.id,'correlation_id',new.correlation_id,'subject_id',new.subject_id,'actor_id',new.actor_id,'event_type',new.event_type,'object_type',new.object_type,'object_ref',new.object_ref,'payload',new.payload,'occurred_at',new.occurred_at,'previous_event_hash',new.previous_event_hash,'chain_version',new.chain_version))::text,'UTF8'),'sha256'::text),'hex');
  return new;
end $$;

drop trigger if exists audit_events_hash_before_insert_trg on sourceenergy_one.audit_events;
create trigger audit_events_hash_before_insert_trg before insert on sourceenergy_one.audit_events for each row execute function sourceenergy_one.audit_events_before_insert_hash();

create or replace function sourceenergy_one.block_audit_event_mutation()
returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin raise exception 'audit_events is append-only'; end $$;

drop trigger if exists audit_events_block_update_trg on sourceenergy_one.audit_events;
drop trigger if exists audit_events_block_delete_trg on sourceenergy_one.audit_events;
create trigger audit_events_block_update_trg before update on sourceenergy_one.audit_events for each row execute function sourceenergy_one.block_audit_event_mutation();
create trigger audit_events_block_delete_trg before delete on sourceenergy_one.audit_events for each row execute function sourceenergy_one.block_audit_event_mutation();

revoke update,delete,truncate on sourceenergy_one.audit_events from public,anon,authenticated,service_role;
grant select,insert on sourceenergy_one.audit_events to service_role;

create or replace function sourceenergy_one.verify_audit_chain()
returns table(id bigint,valid boolean,expected_previous_hash text,stored_previous_hash text,expected_event_hash text,stored_event_hash text)
language sql security definer set search_path=sourceenergy_one,pg_temp as $$
with x as (
 select a.*,lag(a.event_hash) over(order by a.id) expected_prev from sourceenergy_one.audit_events a
), y as (
 select x.id,x.expected_prev,x.previous_event_hash,
 encode(extensions.digest(convert_to((jsonb_build_object('id',x.id,'correlation_id',x.correlation_id,'subject_id',x.subject_id,'actor_id',x.actor_id,'event_type',x.event_type,'object_type',x.object_type,'object_ref',x.object_ref,'payload',x.payload,'occurred_at',x.occurred_at,'previous_event_hash',x.previous_event_hash,'chain_version',x.chain_version))::text,'UTF8'),'sha256'::text),'hex') expected_hash,x.event_hash stored_hash
 from x
)
select id,(expected_prev is not distinct from previous_event_hash) and expected_hash=stored_hash,expected_prev,previous_event_hash,expected_hash,stored_hash from y order by id;
$$;

revoke all on function sourceenergy_one.verify_audit_chain() from public,anon,authenticated;
grant execute on function sourceenergy_one.verify_audit_chain() to service_role;
comment on table sourceenergy_one.audit_events is 'Append-only cryptographically chained SourceEnergy One audit ledger. Mutation is prohibited; verify_audit_chain validates sequence integrity.';
