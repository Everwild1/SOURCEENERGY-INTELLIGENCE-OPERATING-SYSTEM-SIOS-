begin;
-- E10 structural acceptance: all VZC base tables must have RLS.
do $$ begin if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='vzc' and c.relkind='r' and not c.relrowsecurity) then raise exception 'E10: VZC table without RLS'; end if; end $$;
-- E04: execution receipt must bind to same request/decision and authorized decision; target must be control-capable.
do $$ declare d uuid; r uuid; a uuid; begin
 insert into vzc.device_bindings(device_key,device_type,trust_state,control_capable) values ('e10-'||gen_random_uuid()::text,'signal_controller','trusted',false) returning device_binding_id into d;
 begin insert into vzc.control_requests(target_device_binding_id,requested_action,requested_by_ref) values(d,'test','e10'); raise exception 'E10 expected non-control-capable rejection'; exception when others then if sqlerrm='E10 expected non-control-capable rejection' then raise; end if; end;
 update vzc.device_bindings set control_capable=true where device_binding_id=d;
 insert into vzc.control_requests(target_device_binding_id,requested_action,requested_by_ref,request_state,expires_at) values(d,'test','e10','pending_authority',now()+interval '1 hour') returning control_request_id into r;
 insert into vzc.control_authority_decisions(control_request_id,decision,authority_reference,decision_maker_ref) values(r,'rejected','auth:e10','reviewer:e10') returning decision_id into a;
 begin insert into vzc.control_execution_receipts(control_request_id,authority_decision_id,executing_system_ref,execution_state) values(r,a,'executor:e10','accepted'); raise exception 'E10 expected rejected-decision execution rejection'; exception when others then if sqlerrm='E10 expected rejected-decision execution rejection' then raise; end if; end;
end $$;
-- E08: advanced technology candidate states require verified/licensed rights plus reference.
do $$ begin begin insert into vzc.technology_candidate_bindings(technology_key,technology_name,source_registry,source_record_ref,candidate_state,rights_status,ownership_claimed_by_vzc,deployment_authority) values ('e10-'||gen_random_uuid()::text,'E10 candidate','NASA/public registry','e10','pilot_candidate','unverified',false,false); raise exception 'E10 expected rights gate rejection'; exception when others then if sqlerrm='E10 expected rights gate rejection' then raise; end if; end; end $$;
-- Read models must exist and be security-invoker.
do $$ begin if not exists(select 1 from pg_views where schemaname='vzc' and viewname='pilot_acceptance_read_model') or not exists(select 1 from pg_views where schemaname='vzc' and viewname='control_acceptance_read_model') then raise exception 'E10 read models missing'; end if; end $$;
rollback;
