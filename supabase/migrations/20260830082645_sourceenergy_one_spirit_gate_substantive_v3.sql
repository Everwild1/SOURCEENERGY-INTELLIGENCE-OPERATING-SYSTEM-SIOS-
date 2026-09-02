alter table sourceenergy_one.spirit_gate_assessments add column if not exists dimension_findings jsonb;
alter table sourceenergy_one.spirit_gate_assessments add column if not exists doctrine_mapping jsonb;
alter table sourceenergy_one.spirit_gate_assessments add column if not exists doctrine_hash text;

create or replace function sourceenergy_one.assess_spirit_gate_v3(
 p_subject_id text,
 p_object_type text,
 p_object_ref uuid,
 p_dimension_findings jsonb,
 p_actor_ref text,
 p_consent_scope_id text
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
 aid uuid;
 resolved_subject text;
 canonical jsonb := jsonb_build_object(
   'fear','integrity / fiduciary boundary / compliance',
   'presence','mission and values alignment',
   'wisdom','architecture and strategic design',
   'knowledge','evidence, intelligence and data governance',
   'understanding','integration and systems coherence',
   'counsel','decision rights, review and authorization',
   'might','controlled execution, deployment and completion'
 );
 ordered jsonb := '["fear","presence","wisdom","knowledge","understanding","counsel","might"]'::jsonb;
 k text;
 finding jsonb;
 ah text;
 dh text;
begin
 if nullif(btrim(p_subject_id),'') is null or nullif(btrim(p_object_type),'') is null or nullif(btrim(p_actor_ref),'') is null or nullif(btrim(p_consent_scope_id),'') is null then raise exception 'subject, object type, actor and consent scope required'; end if;
 resolved_subject:=sourceenergy_one.spirit_gate_object_subject(btrim(p_object_type),p_object_ref);
 if resolved_subject<>btrim(p_subject_id) then raise exception 'Spirit Gate subject does not match source object'; end if;
 if p_dimension_findings is null or jsonb_typeof(p_dimension_findings)<>'object' then raise exception 'Spirit Gate v3 requires substantive dimension findings object'; end if;
 for k in select jsonb_array_elements_text(ordered) loop
   finding:=p_dimension_findings->k;
   if finding is null or jsonb_typeof(finding)<>'object' then raise exception 'Spirit Gate v3 missing finding for %',k; end if;
   if nullif(btrim(finding->>'assessment'),'') is null then raise exception 'Spirit Gate v3 % assessment required',k; end if;
   if nullif(btrim(finding->>'rationale'),'') is null then raise exception 'Spirit Gate v3 % rationale required',k; end if;
   if finding->>'disposition' not in ('aligned','hold') then raise exception 'Spirit Gate v3 % disposition must be aligned or hold',k; end if;
 end loop;
 dh:=encode(extensions.digest(convert_to(canonical::text,'UTF8'),'sha256'::text),'hex');
 ah:=encode(extensions.digest(convert_to((jsonb_build_object('order',ordered,'mapping',canonical,'findings',p_dimension_findings))::text,'UTF8'),'sha256'::text),'hex');
 insert into sourceenergy_one.spirit_gate_assessments(subject_id,object_type,object_ref,gate_version,dimensions,dimension_findings,doctrine_mapping,doctrine_hash,assessment_hash,status,assessed_by_actor_ref,consent_scope_id)
 values(btrim(p_subject_id),btrim(p_object_type),p_object_ref,'spirit-gate-v3',ordered,p_dimension_findings,canonical,dh,ah,'assessed',btrim(p_actor_ref),btrim(p_consent_scope_id)) returning id into aid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'spirit_gate_v3_assessed','spirit_gate_assessment',aid::text,jsonb_build_object('source_object_type',btrim(p_object_type),'source_object_ref',p_object_ref,'gate_version','spirit-gate-v3','assessment_hash',ah,'doctrine_hash',dh));
 return aid;
end;
$$;

create or replace function sourceenergy_one.review_spirit_gate_v3(
 p_assessment_id uuid,
 p_decision text,
 p_actor_ref text,
 p_attestation text
) returns text
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare a sourceenergy_one.spirit_gate_assessments%rowtype; k text; finding jsonb;
begin
 if p_decision not in ('human_confirmed','rejected') then raise exception 'Spirit Gate v3 review decision must be human_confirmed or rejected'; end if;
 if nullif(btrim(p_actor_ref),'') is null or nullif(btrim(p_attestation),'') is null then raise exception 'human actor and attestation required'; end if;
 select * into a from sourceenergy_one.spirit_gate_assessments where id=p_assessment_id for update;
 if not found then raise exception 'Spirit Gate assessment not found'; end if;
 if a.gate_version<>'spirit-gate-v3' then raise exception 'Spirit Gate v3 assessment required'; end if;
 if a.status<>'assessed' then raise exception 'Spirit Gate assessment already reviewed'; end if;
 if p_decision='human_confirmed' then
   for k in select jsonb_array_elements_text(a.dimensions) loop
     finding:=a.dimension_findings->k;
     if finding->>'disposition'<>'aligned' then raise exception 'Spirit Gate v3 cannot be confirmed while % is on hold',k; end if;
   end loop;
 end if;
 update sourceenergy_one.spirit_gate_assessments set status=p_decision,human_reviewed_by_actor_ref=btrim(p_actor_ref),human_reviewed_at=now(),human_attestation=btrim(p_attestation) where id=a.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),a.subject_id,auth.uid(),'spirit_gate_v3_'||p_decision,'spirit_gate_assessment',a.id::text,jsonb_build_object('source_object_type',a.object_type,'source_object_ref',a.object_ref,'actor_ref',btrim(p_actor_ref),'gate_version',a.gate_version));
 return p_decision;
end;
$$;

create or replace function sourceenergy_one.require_spirit_gate(p_object_type text,p_object_ref uuid) returns boolean
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
begin
 if not exists(
   select 1 from sourceenergy_one.spirit_gate_assessments a
   where a.object_type=p_object_type and a.object_ref=p_object_ref and a.gate_version='spirit-gate-v3' and a.status='human_confirmed'
     and a.dimension_findings is not null
     and not exists(select 1 from jsonb_array_elements_text(a.dimensions) d(k) where a.dimension_findings->d.k->>'disposition'<>'aligned')
 ) then raise exception 'Spirit Gate v3 not satisfied for % %',p_object_type,p_object_ref; end if;
 return true;
end;
$$;

revoke all on function sourceenergy_one.assess_spirit_gate_v3(text,text,uuid,jsonb,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.review_spirit_gate_v3(uuid,text,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.assess_spirit_gate_v3(text,text,uuid,jsonb,text,text) to service_role;
grant execute on function sourceenergy_one.review_spirit_gate_v3(uuid,text,text,text) to service_role;

revoke execute on function sourceenergy_one.assess_spirit_gate(text,text,uuid,jsonb,text,text) from service_role;
revoke execute on function sourceenergy_one.review_spirit_gate(uuid,text,text,text) from service_role;
comment on function sourceenergy_one.assess_spirit_gate(text,text,uuid,jsonb,text,text) is 'Deprecated legacy Spirit Gate v1 assessor. Use assess_spirit_gate_v3.';
comment on function sourceenergy_one.review_spirit_gate(uuid,text,text,text) is 'Deprecated legacy Spirit Gate review. Use review_spirit_gate_v3.';
comment on function sourceenergy_one.require_spirit_gate(text,uuid) is 'Fail-closed substantive Spirit Gate v3. Requires human-confirmed findings across Fear, Presence, Wisdom, Knowledge, Understanding, Counsel, Might with every disposition aligned.';
