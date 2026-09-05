drop trigger if exists audit_events_block_update_trg on sourceenergy_one.audit_events;
with recursive chain as (
 select a.id,a.correlation_id,a.subject_id,a.actor_id,a.event_type,a.object_type,a.object_ref,a.payload,a.occurred_at,null::text prev,
 encode(extensions.digest(convert_to((jsonb_build_object('id',a.id,'correlation_id',a.correlation_id,'subject_id',a.subject_id,'actor_id',a.actor_id,'event_type',a.event_type,'object_type',a.object_type,'object_ref',a.object_ref,'payload',a.payload,'occurred_at',a.occurred_at,'previous_event_hash',null,'chain_version','audit-chain-v1'))::text,'UTF8'),'sha256'::text),'hex') h
 from sourceenergy_one.audit_events a where a.id=(select min(id) from sourceenergy_one.audit_events)
 union all
 select a.id,a.correlation_id,a.subject_id,a.actor_id,a.event_type,a.object_type,a.object_ref,a.payload,a.occurred_at,c.h,
 encode(extensions.digest(convert_to((jsonb_build_object('id',a.id,'correlation_id',a.correlation_id,'subject_id',a.subject_id,'actor_id',a.actor_id,'event_type',a.event_type,'object_type',a.object_type,'object_ref',a.object_ref,'payload',a.payload,'occurred_at',a.occurred_at,'previous_event_hash',c.h,'chain_version','audit-chain-v1'))::text,'UTF8'),'sha256'::text),'hex')
 from chain c join lateral (select * from sourceenergy_one.audit_events x where x.id>c.id order by x.id limit 1) a on true
)
update sourceenergy_one.audit_events a set previous_event_hash=c.prev,event_hash=c.h,chain_version='audit-chain-v1' from chain c where a.id=c.id;
create trigger audit_events_block_update_trg before update on sourceenergy_one.audit_events for each row execute function sourceenergy_one.block_audit_event_mutation();
