create or replace function sourceenergy_one.promote_confirmed_knowledge_to_reflection(
 p_insight_id uuid,
 p_synthesis_version text,
 p_model_provenance jsonb
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
 k sourceenergy_one.knowledge_insights%rowtype;
 rid uuid;
 changes jsonb;
begin
 select * into k from sourceenergy_one.knowledge_insights where id=p_insight_id for update;
 if not found then raise exception 'knowledge insight not found'; end if;
 if k.authority_status<>'human_confirmed' then raise exception 'knowledge insight must be human-confirmed'; end if;
 if k.materiality='none' then raise exception 'non-material knowledge insight does not enter Purpose/4P evolution pipeline'; end if;
 if nullif(btrim(p_synthesis_version),'') is null then raise exception 'synthesis_version required'; end if;
 perform sourceenergy_one.require_ai_inference_provenance('knowledge_insight',k.id,k.subject_id);
 changes:=jsonb_build_object('source_knowledge_insight_id',k.id,'related_4p_dimensions',to_jsonb(k.related_4p_dimensions),'knowledge_insight',k.insight);
 insert into sourceenergy_one.purpose_reflection_syntheses(subject_id,source_entry_ids,source_hashes,synthesis_version,model_provenance,signals_4p,materiality,proposed_changes,consent_scope_id,human_review_status,reviewed_by_actor_ref,reviewed_at,review_attestation)
 values(k.subject_id,k.source_artifact_ids,k.source_hashes,btrim(p_synthesis_version),coalesce(p_model_provenance,'{}'::jsonb),jsonb_build_object('knowledge_insight_id',k.id,'related_4p_dimensions',to_jsonb(k.related_4p_dimensions)),k.materiality,changes,k.consent_scope_id,'pending',null,null,null)
 returning id into rid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),k.subject_id,auth.uid(),'knowledge_insight_promoted_to_pending_reflection','purpose_reflection_synthesis',rid::text,jsonb_build_object('knowledge_insight_id',k.id,'materiality',k.materiality,'related_4p_dimensions',k.related_4p_dimensions,'review_status','pending'));
 return rid;
end;
$$;

create or replace function sourceenergy_one.block_confirmed_reflection_insert()
returns trigger
language plpgsql
set search_path=sourceenergy_one,pg_temp
as $$
begin
 if new.human_review_status='confirmed' then
   raise exception 'reflection cannot be inserted pre-confirmed; use governed review transition';
 end if;
 return new;
end;
$$;

drop trigger if exists purpose_reflection_block_preconfirmed_insert_trg on sourceenergy_one.purpose_reflection_syntheses;
create trigger purpose_reflection_block_preconfirmed_insert_trg
before insert on sourceenergy_one.purpose_reflection_syntheses
for each row execute function sourceenergy_one.block_confirmed_reflection_insert();

revoke all on function sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb) to service_role;
comment on function sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb) is 'Promotes a human-confirmed knowledge insight into a PENDING Purpose/4P reflection. Final confirmation must traverse typed evidence, Spirit Gate V3, verified actor, governed consent, and AI inference provenance checks.';
