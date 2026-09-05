create or replace function sourceenergy_one.create_knowledge_insight(
 p_cycle_id uuid,
 p_source_artifact_ids uuid[],
 p_codex24_version text,
 p_insight jsonb,
 p_related_4p_dimensions text[],
 p_materiality text,
 p_consent_scope_id text
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
 c sourceenergy_one.knowledge_cycles%rowtype;
 insight_id uuid;
 hashes text[];
begin
 select * into c from sourceenergy_one.knowledge_cycles where id=p_cycle_id for update;
 if not found or c.status<>'active' then raise exception 'active knowledge cycle required'; end if;
 if p_source_artifact_ids is null or cardinality(p_source_artifact_ids)=0 then raise exception 'source_artifact_ids required'; end if;
 if nullif(btrim(p_codex24_version),'') is null then raise exception 'codex24_version required'; end if;
 if p_insight is null or jsonb_typeof(p_insight)<>'object' then raise exception 'insight object required'; end if;
 if p_materiality not in ('none','minor','material') then raise exception 'invalid materiality'; end if;
 if nullif(btrim(p_consent_scope_id),'') is null then raise exception 'consent scope required'; end if;
 if p_related_4p_dimensions is null or not (p_related_4p_dimensions <@ array['purpose','product','people','profit']::text[]) then raise exception 'invalid 4P dimensions'; end if;
 if exists(select 1 from unnest(p_source_artifact_ids) x(id) left join sourceenergy_one.knowledge_artifacts a on a.id=x.id where a.id is null or a.cycle_id<>c.id or a.subject_id<>c.subject_id or a.visibility in ('private','cycle_only') or a.consent_scope_id<>p_consent_scope_id) then raise exception 'source artifacts not eligible for Codex24 insight under consent scope'; end if;
 select array_agg(a.content_hash order by a.id) into hashes from sourceenergy_one.knowledge_artifacts a where a.id=any(p_source_artifact_ids);
 insert into sourceenergy_one.knowledge_insights(cycle_id,subject_id,source_artifact_ids,source_hashes,codex24_version,insight,related_4p_dimensions,materiality,authority_status,consent_scope_id)
 values(c.id,c.subject_id,p_source_artifact_ids,hashes,btrim(p_codex24_version),p_insight,coalesce(p_related_4p_dimensions,'{}'::text[]),p_materiality,'counsel',btrim(p_consent_scope_id)) returning id into insight_id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),c.subject_id,auth.uid(),'knowledge_insight_created','knowledge_insight',insight_id::text,jsonb_build_object('cycle_id',c.id,'materiality',p_materiality,'related_4p_dimensions',p_related_4p_dimensions,'authority_status','counsel'));
 return insight_id;
end;
$$;

create or replace function sourceenergy_one.review_knowledge_insight(
 p_insight_id uuid,
 p_decision text,
 p_actor_ref text,
 p_attestation text
) returns text
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare k sourceenergy_one.knowledge_insights%rowtype;
begin
 if p_decision not in ('human_confirmed','rejected') then raise exception 'invalid insight review decision'; end if;
 if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
 if nullif(btrim(p_attestation),'') is null then raise exception 'attestation required'; end if;
 select * into k from sourceenergy_one.knowledge_insights where id=p_insight_id for update;
 if not found then raise exception 'knowledge insight not found'; end if;
 if k.authority_status<>'counsel' then raise exception 'knowledge insight already reviewed'; end if;
 update sourceenergy_one.knowledge_insights set authority_status=p_decision,reviewed_by_actor_ref=btrim(p_actor_ref),reviewed_at=now(),review_attestation=btrim(p_attestation) where id=k.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),k.subject_id,auth.uid(),'knowledge_insight_'||p_decision,'knowledge_insight',k.id::text,jsonb_build_object('actor_ref',btrim(p_actor_ref),'materiality',k.materiality,'related_4p_dimensions',k.related_4p_dimensions));
 return p_decision;
end;
$$;

create or replace function sourceenergy_one.promote_confirmed_knowledge_to_reflection(
 p_insight_id uuid,
 p_synthesis_version text,
 p_model_provenance jsonb
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare k sourceenergy_one.knowledge_insights%rowtype; rid uuid; changes jsonb;
begin
 select * into k from sourceenergy_one.knowledge_insights where id=p_insight_id for update;
 if not found then raise exception 'knowledge insight not found'; end if;
 if k.authority_status<>'human_confirmed' then raise exception 'knowledge insight must be human-confirmed'; end if;
 if k.materiality='none' then raise exception 'non-material knowledge insight does not enter Purpose/4P evolution pipeline'; end if;
 if nullif(btrim(p_synthesis_version),'') is null then raise exception 'synthesis_version required'; end if;
 changes:=jsonb_build_object('source_knowledge_insight_id',k.id,'related_4p_dimensions',to_jsonb(k.related_4p_dimensions),'knowledge_insight',k.insight);
 insert into sourceenergy_one.purpose_reflection_syntheses(subject_id,source_entry_ids,source_hashes,synthesis_version,model_provenance,signals_4p,materiality,proposed_changes,consent_scope_id,human_review_status,reviewed_by_actor_ref,reviewed_at,review_attestation)
 values(k.subject_id,k.source_artifact_ids,k.source_hashes,btrim(p_synthesis_version),coalesce(p_model_provenance,'{}'::jsonb),jsonb_build_object('knowledge_insight_id',k.id,'related_4p_dimensions',to_jsonb(k.related_4p_dimensions)),k.materiality,changes,k.consent_scope_id,'confirmed',k.reviewed_by_actor_ref,k.reviewed_at,k.review_attestation) returning id into rid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),k.subject_id,auth.uid(),'knowledge_insight_promoted_to_reflection','purpose_reflection_synthesis',rid::text,jsonb_build_object('knowledge_insight_id',k.id,'materiality',k.materiality,'related_4p_dimensions',k.related_4p_dimensions));
 return rid;
end;
$$;

revoke all on function sourceenergy_one.create_knowledge_insight(uuid,uuid[],text,jsonb,text[],text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.review_knowledge_insight(uuid,text,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function sourceenergy_one.create_knowledge_insight(uuid,uuid[],text,jsonb,text[],text,text) to service_role;
grant execute on function sourceenergy_one.review_knowledge_insight(uuid,text,text,text) to service_role;
grant execute on function sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb) to service_role;
