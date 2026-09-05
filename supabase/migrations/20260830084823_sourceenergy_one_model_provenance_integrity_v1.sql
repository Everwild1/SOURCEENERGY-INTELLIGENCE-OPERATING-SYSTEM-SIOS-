create table if not exists sourceenergy_one.model_provenance_registry (
 id uuid primary key default gen_random_uuid(),
 provider text not null,
 model_name text not null,
 model_version text not null,
 system_policy_version text not null,
 prompt_template_hash text not null check(prompt_template_hash ~ '^[0-9a-f]{64}$'),
 tool_policy_hash text not null check(tool_policy_hash ~ '^[0-9a-f]{64}$'),
 provenance_metadata jsonb not null default '{}'::jsonb,
 status text not null default 'active' check(status in ('active','deprecated','revoked')),
 registered_by_actor_ref text not null,
 registered_at timestamptz not null default now(),
 unique(provider,model_name,model_version,system_policy_version,prompt_template_hash,tool_policy_hash)
);

create table if not exists sourceenergy_one.ai_inference_records (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 inference_type text not null check(inference_type in ('codex24_interpretation','knowledge_insight','purpose_reflection','other')),
 source_object_type text not null,
 source_object_ref uuid not null,
 model_provenance_id uuid not null references sourceenergy_one.model_provenance_registry(id),
 input_evidence_ids uuid[] not null,
 input_hash text not null check(input_hash ~ '^[0-9a-f]{64}$'),
 output_hash text not null check(output_hash ~ '^[0-9a-f]{64}$'),
 authority_class text not null default 'counsel' check(authority_class in ('counsel','human_confirmed','rejected')),
 consent_scope_id text not null,
 created_at timestamptz not null default now(),
 constraint ai_inference_evidence_nonempty_ck check(cardinality(input_evidence_ids)>0)
);

alter table sourceenergy_one.model_provenance_registry enable row level security;
alter table sourceenergy_one.ai_inference_records enable row level security;
revoke all on sourceenergy_one.model_provenance_registry,sourceenergy_one.ai_inference_records from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.model_provenance_registry,sourceenergy_one.ai_inference_records to service_role;
create policy model_provenance_service_role on sourceenergy_one.model_provenance_registry for all to service_role using(true) with check(true);
create policy ai_inference_service_role on sourceenergy_one.ai_inference_records for all to service_role using(true) with check(true);

create or replace function sourceenergy_one.register_model_provenance(p_provider text,p_model_name text,p_model_version text,p_system_policy_version text,p_prompt_template_hash text,p_tool_policy_hash text,p_actor_ref text,p_metadata jsonb default '{}'::jsonb) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare rid uuid; begin
 if nullif(btrim(p_provider),'') is null or nullif(btrim(p_model_name),'') is null or nullif(btrim(p_model_version),'') is null or nullif(btrim(p_system_policy_version),'') is null then raise exception 'provider, model, version and system policy version required'; end if;
 if p_prompt_template_hash !~ '^[0-9a-f]{64}$' or p_tool_policy_hash !~ '^[0-9a-f]{64}$' then raise exception 'provenance hashes must be 64 lowercase hex'; end if;
 perform sourceenergy_one.require_verified_actor(p_actor_ref,null,'verified');
 insert into sourceenergy_one.model_provenance_registry(provider,model_name,model_version,system_policy_version,prompt_template_hash,tool_policy_hash,registered_by_actor_ref,provenance_metadata)
 values(btrim(p_provider),btrim(p_model_name),btrim(p_model_version),btrim(p_system_policy_version),p_prompt_template_hash,p_tool_policy_hash,btrim(p_actor_ref),coalesce(p_metadata,'{}'::jsonb)) returning id into rid;
 return rid;
end $$;

create or replace function sourceenergy_one.record_ai_inference(p_subject_id text,p_inference_type text,p_source_object_type text,p_source_object_ref uuid,p_model_provenance_id uuid,p_input_evidence_ids uuid[],p_output jsonb,p_consent_scope_id text) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare rid uuid; ih text; oh text; eid uuid; m sourceenergy_one.model_provenance_registry%rowtype; begin
 if p_inference_type not in ('codex24_interpretation','knowledge_insight','purpose_reflection','other') then raise exception 'invalid inference type'; end if;
 if p_input_evidence_ids is null or cardinality(p_input_evidence_ids)=0 then raise exception 'typed input evidence required'; end if;
 select * into m from sourceenergy_one.model_provenance_registry where id=p_model_provenance_id and status='active'; if not found then raise exception 'active model provenance required'; end if;
 foreach eid in array p_input_evidence_ids loop perform sourceenergy_one.require_evidence_provenance(eid,p_subject_id); end loop;
 perform sourceenergy_one.require_active_consent(p_consent_scope_id,p_subject_id,null);
 select encode(extensions.digest(convert_to((jsonb_agg(jsonb_build_object('id',e.id,'hash',e.evidence_hash) order by e.id))::text,'UTF8'),'sha256'::text),'hex') into ih from sourceenergy_one.evidence_provenance e where e.id=any(p_input_evidence_ids);
 oh:=encode(extensions.digest(convert_to(coalesce(p_output,'{}'::jsonb)::text,'UTF8'),'sha256'::text),'hex');
 insert into sourceenergy_one.ai_inference_records(subject_id,inference_type,source_object_type,source_object_ref,model_provenance_id,input_evidence_ids,input_hash,output_hash,authority_class,consent_scope_id)
 values(btrim(p_subject_id),p_inference_type,btrim(p_source_object_type),p_source_object_ref,p_model_provenance_id,p_input_evidence_ids,ih,oh,'counsel',btrim(p_consent_scope_id)) returning id into rid;
 return rid;
end $$;

create or replace function sourceenergy_one.require_ai_inference_provenance(p_source_object_type text,p_source_object_ref uuid,p_subject_id text) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare r sourceenergy_one.ai_inference_records%rowtype; begin
 select * into r from sourceenergy_one.ai_inference_records where source_object_type=p_source_object_type and source_object_ref=p_source_object_ref and subject_id=p_subject_id order by created_at desc limit 1;
 if not found then raise exception 'AI inference provenance required'; end if;
 if not exists(select 1 from sourceenergy_one.model_provenance_registry m where m.id=r.model_provenance_id and m.status='active') then raise exception 'AI inference model provenance not active'; end if;
 return r.id;
end $$;

create or replace function sourceenergy_one.enforce_knowledge_insight_ai_provenance() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin
 if old.authority_status='counsel' and new.authority_status='human_confirmed' then perform sourceenergy_one.require_ai_inference_provenance('knowledge_insight',new.id,new.subject_id); end if; return new;
end $$;
drop trigger if exists knowledge_insight_ai_provenance_confirm_trg on sourceenergy_one.knowledge_insights;
create trigger knowledge_insight_ai_provenance_confirm_trg before update on sourceenergy_one.knowledge_insights for each row execute function sourceenergy_one.enforce_knowledge_insight_ai_provenance();

create or replace function sourceenergy_one.enforce_reflection_ai_provenance() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin
 if old.human_review_status='pending' and new.human_review_status='confirmed' then perform sourceenergy_one.require_ai_inference_provenance('purpose_reflection_synthesis',new.id,new.subject_id); end if; return new;
end $$;
drop trigger if exists purpose_reflection_ai_provenance_confirm_trg on sourceenergy_one.purpose_reflection_syntheses;
create trigger purpose_reflection_ai_provenance_confirm_trg before update on sourceenergy_one.purpose_reflection_syntheses for each row execute function sourceenergy_one.enforce_reflection_ai_provenance();

revoke all on function sourceenergy_one.register_model_provenance(text,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function sourceenergy_one.record_ai_inference(text,text,text,uuid,uuid,uuid[],jsonb,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.require_ai_inference_provenance(text,uuid,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.register_model_provenance(text,text,text,text,text,text,text,jsonb) to service_role;
grant execute on function sourceenergy_one.record_ai_inference(text,text,text,uuid,uuid,uuid[],jsonb,text) to service_role;
grant execute on function sourceenergy_one.require_ai_inference_provenance(text,uuid,text) to service_role;
comment on table sourceenergy_one.model_provenance_registry is 'Governed AI model/provider/policy provenance registry. AI output remains counsel unless separately human-confirmed.';
comment on table sourceenergy_one.ai_inference_records is 'Hashes typed evidence inputs and AI outputs against governed model provenance and consent.';
