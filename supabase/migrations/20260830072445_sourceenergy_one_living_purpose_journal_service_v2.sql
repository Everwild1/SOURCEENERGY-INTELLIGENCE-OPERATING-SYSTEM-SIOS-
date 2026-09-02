create or replace function sourceenergy_one.create_living_purpose_journal_entry(
  p_subject_id text,
  p_protected_content jsonb,
  p_consent_scope_id text,
  p_visibility text,
  p_source_type text,
  p_actor_ref text,
  p_effective_at timestamptz default null,
  p_prior_entry_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
  entry_id uuid;
  content_hash text;
begin
  if p_subject_id is null or btrim(p_subject_id)='' then raise exception 'subject_id required'; end if;
  if p_protected_content is null or jsonb_typeof(p_protected_content)<>'object' then raise exception 'protected_content must be a JSON object'; end if;
  if p_consent_scope_id is null or btrim(p_consent_scope_id)='' then raise exception 'consent_scope_id required'; end if;
  if p_visibility not in ('private','reflection_only','approved_derived_use') then raise exception 'invalid visibility'; end if;
  if p_source_type is null or btrim(p_source_type)='' then raise exception 'source_type required'; end if;
  if p_actor_ref is null or btrim(p_actor_ref)='' then raise exception 'actor_ref required'; end if;
  if p_prior_entry_id is not null and not exists(select 1 from sourceenergy_one.living_purpose_journal_entries e where e.id=p_prior_entry_id and e.subject_id=p_subject_id) then
    raise exception 'prior_entry_id does not belong to subject';
  end if;
  content_hash:=encode(extensions.digest(convert_to(p_protected_content::text,'UTF8'),'sha256'::text),'hex');
  insert into sourceenergy_one.living_purpose_journal_entries(subject_id,effective_at,protected_content,content_hash,consent_scope_id,visibility,source_type,prior_entry_id,actor_ref)
  values(btrim(p_subject_id),p_effective_at,p_protected_content,content_hash,btrim(p_consent_scope_id),p_visibility,btrim(p_source_type),p_prior_entry_id,btrim(p_actor_ref)) returning id into entry_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'living_purpose_journal_entry_created','living_purpose_journal_entry',entry_id::text,jsonb_build_object('content_hash',content_hash,'consent_scope_id',btrim(p_consent_scope_id),'visibility',p_visibility,'source_type',btrim(p_source_type),'actor_ref',btrim(p_actor_ref)));
  return entry_id;
end;
$$;

create or replace function sourceenergy_one.withdraw_living_purpose_journal_entry(
  p_entry_id uuid,
  p_actor_ref text,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare e sourceenergy_one.living_purpose_journal_entries%rowtype;
begin
  if p_actor_ref is null or btrim(p_actor_ref)='' then raise exception 'actor_ref required'; end if;
  select * into e from sourceenergy_one.living_purpose_journal_entries where id=p_entry_id for update;
  if not found then raise exception 'journal entry not found'; end if;
  if e.status<>'active' then raise exception 'journal entry is not active'; end if;
  update sourceenergy_one.living_purpose_journal_entries set status='withdrawn' where id=p_entry_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),e.subject_id,auth.uid(),'living_purpose_journal_entry_withdrawn','living_purpose_journal_entry',e.id::text,jsonb_build_object('actor_ref',btrim(p_actor_ref),'reason',p_reason));
end;
$$;

create or replace function sourceenergy_one.create_purpose_reflection_synthesis(
  p_subject_id text,
  p_source_entry_ids uuid[],
  p_synthesis_version text,
  p_model_provenance jsonb,
  p_signals_4p jsonb,
  p_materiality text,
  p_proposed_changes jsonb,
  p_consent_scope_id text
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
  synthesis_id uuid;
  source_hashes text[];
begin
  if p_subject_id is null or btrim(p_subject_id)='' then raise exception 'subject_id required'; end if;
  if p_source_entry_ids is null or cardinality(p_source_entry_ids)=0 then raise exception 'source_entry_ids required'; end if;
  if p_synthesis_version is null or btrim(p_synthesis_version)='' then raise exception 'synthesis_version required'; end if;
  if p_signals_4p is null or jsonb_typeof(p_signals_4p)<>'object' then raise exception 'signals_4p must be an object'; end if;
  if p_materiality not in ('none','minor','material') then raise exception 'invalid materiality'; end if;
  if p_consent_scope_id is null or btrim(p_consent_scope_id)='' then raise exception 'consent_scope_id required'; end if;
  if exists(select 1 from unnest(p_source_entry_ids) x(id) left join sourceenergy_one.living_purpose_journal_entries e on e.id=x.id where e.id is null or e.subject_id<>p_subject_id or e.status<>'active' or e.visibility='private' or e.consent_scope_id<>p_consent_scope_id) then
    raise exception 'source entries are not eligible for reflection under this consent scope';
  end if;
  select array_agg(e.content_hash order by e.id) into source_hashes from sourceenergy_one.living_purpose_journal_entries e where e.id=any(p_source_entry_ids);
  insert into sourceenergy_one.purpose_reflection_syntheses(subject_id,source_entry_ids,source_hashes,synthesis_version,model_provenance,signals_4p,materiality,proposed_changes,consent_scope_id)
  values(btrim(p_subject_id),p_source_entry_ids,source_hashes,btrim(p_synthesis_version),coalesce(p_model_provenance,'{}'::jsonb),p_signals_4p,p_materiality,coalesce(p_proposed_changes,'{}'::jsonb),btrim(p_consent_scope_id)) returning id into synthesis_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'purpose_reflection_synthesis_created','purpose_reflection_synthesis',synthesis_id::text,jsonb_build_object('source_entry_ids',p_source_entry_ids,'materiality',p_materiality,'consent_scope_id',btrim(p_consent_scope_id)));
  return synthesis_id;
end;
$$;

create or replace function sourceenergy_one.review_purpose_reflection_synthesis(
  p_synthesis_id uuid,
  p_decision text,
  p_actor_ref text,
  p_attestation text
) returns text
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare r sourceenergy_one.purpose_reflection_syntheses%rowtype;
begin
  if p_decision not in ('confirmed','rejected','revision_requested') then raise exception 'invalid review decision'; end if;
  if p_actor_ref is null or btrim(p_actor_ref)='' then raise exception 'actor_ref required'; end if;
  if p_attestation is null or btrim(p_attestation)='' then raise exception 'attestation required'; end if;
  select * into r from sourceenergy_one.purpose_reflection_syntheses where id=p_synthesis_id for update;
  if not found then raise exception 'reflection synthesis not found'; end if;
  if r.human_review_status<>'pending' then raise exception 'reflection synthesis is not pending'; end if;
  update sourceenergy_one.purpose_reflection_syntheses set human_review_status=p_decision,reviewed_by_actor_ref=btrim(p_actor_ref),reviewed_at=now(),review_attestation=btrim(p_attestation) where id=p_synthesis_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),r.subject_id,auth.uid(),'purpose_reflection_'||p_decision,'purpose_reflection_synthesis',r.id::text,jsonb_build_object('actor_ref',btrim(p_actor_ref),'materiality',r.materiality,'attestation',btrim(p_attestation)));
  return p_decision;
end;
$$;

revoke all on function sourceenergy_one.create_living_purpose_journal_entry(text,jsonb,text,text,text,text,timestamptz,uuid) from public,anon,authenticated;
revoke all on function sourceenergy_one.withdraw_living_purpose_journal_entry(uuid,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.create_purpose_reflection_synthesis(text,uuid[],text,jsonb,jsonb,text,jsonb,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.review_purpose_reflection_synthesis(uuid,text,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.create_living_purpose_journal_entry(text,jsonb,text,text,text,text,timestamptz,uuid) to service_role;
grant execute on function sourceenergy_one.withdraw_living_purpose_journal_entry(uuid,text,text) to service_role;
grant execute on function sourceenergy_one.create_purpose_reflection_synthesis(text,uuid[],text,jsonb,jsonb,text,jsonb,text) to service_role;
grant execute on function sourceenergy_one.review_purpose_reflection_synthesis(uuid,text,text,text) to service_role;
