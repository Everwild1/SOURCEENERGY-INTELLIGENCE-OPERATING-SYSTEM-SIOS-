create table if not exists sourceenergy_one.spirit_gate_assessments (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 object_type text not null,
 object_ref uuid not null,
 gate_version text not null default 'spirit-gate-v1',
 dimensions jsonb not null,
 assessment_hash text not null check(assessment_hash ~ '^[0-9a-f]{64}$'),
 status text not null default 'assessed' check(status in ('assessed','human_confirmed','rejected','exempted')),
 assessed_by_actor_ref text not null,
 consent_scope_id text not null,
 human_reviewed_by_actor_ref text,
 human_reviewed_at timestamptz,
 human_attestation text,
 created_at timestamptz not null default now(),
 unique(object_type,object_ref,gate_version)
);
alter table sourceenergy_one.spirit_gate_assessments enable row level security;
revoke all on sourceenergy_one.spirit_gate_assessments from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.spirit_gate_assessments to service_role;
create policy spirit_gate_service_role on sourceenergy_one.spirit_gate_assessments for all to service_role using(true) with check(true);
create index if not exists spirit_gate_subject_idx on sourceenergy_one.spirit_gate_assessments(subject_id,created_at desc);
comment on table sourceenergy_one.spirit_gate_assessments is 'SourceEnergy One Seven Dimensions Spirit Gate. Canonical ordered progression: Fear -> Presence -> Wisdom -> Knowledge -> Understanding -> Counsel -> Might.';

create or replace function sourceenergy_one.assess_spirit_gate(
 p_subject_id text,p_object_type text,p_object_ref uuid,p_dimensions jsonb,p_actor_ref text,p_consent_scope_id text
) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare aid uuid; h text; expected text[]:=array['fear','presence','wisdom','knowledge','understanding','counsel','might']; k text; i int:=0;
begin
 if nullif(btrim(p_subject_id),'') is null or nullif(btrim(p_object_type),'') is null or nullif(btrim(p_actor_ref),'') is null or nullif(btrim(p_consent_scope_id),'') is null then raise exception 'subject, object type, actor and consent scope required'; end if;
 if p_object_ref is null then raise exception 'object_ref required'; end if;
 if p_dimensions is null or jsonb_typeof(p_dimensions)<>'array' or jsonb_array_length(p_dimensions)<>7 then raise exception 'Spirit Gate requires exactly seven ordered dimensions'; end if;
 for k in select jsonb_array_elements_text(p_dimensions) loop i:=i+1; if lower(k)<>expected[i] then raise exception 'invalid Spirit Gate order at position %: expected %',i,expected[i]; end if; end loop;
 h:=encode(extensions.digest(convert_to(p_dimensions::text,'UTF8'),'sha256'::text),'hex');
 insert into sourceenergy_one.spirit_gate_assessments(subject_id,object_type,object_ref,dimensions,assessment_hash,assessed_by_actor_ref,consent_scope_id)
 values(btrim(p_subject_id),btrim(p_object_type),p_object_ref,p_dimensions,h,btrim(p_actor_ref),btrim(p_consent_scope_id)) returning id into aid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'spirit_gate_assessed','spirit_gate_assessment',aid::text,jsonb_build_object('source_object_type',btrim(p_object_type),'source_object_ref',p_object_ref,'gate_version','spirit-gate-v1','assessment_hash',h));
 return aid;
end $$;

create or replace function sourceenergy_one.review_spirit_gate(p_assessment_id uuid,p_decision text,p_actor_ref text,p_attestation text) returns text language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare a sourceenergy_one.spirit_gate_assessments%rowtype;
begin
 if p_decision not in ('human_confirmed','rejected','exempted') then raise exception 'invalid Spirit Gate review decision'; end if;
 if nullif(btrim(p_actor_ref),'') is null or nullif(btrim(p_attestation),'') is null then raise exception 'human actor and attestation required'; end if;
 select * into a from sourceenergy_one.spirit_gate_assessments where id=p_assessment_id for update; if not found then raise exception 'Spirit Gate assessment not found'; end if;
 if a.status<>'assessed' then raise exception 'Spirit Gate assessment already reviewed'; end if;
 update sourceenergy_one.spirit_gate_assessments set status=p_decision,human_reviewed_by_actor_ref=btrim(p_actor_ref),human_reviewed_at=now(),human_attestation=btrim(p_attestation) where id=a.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),a.subject_id,auth.uid(),'spirit_gate_'||p_decision,'spirit_gate_assessment',a.id::text,jsonb_build_object('source_object_type',a.object_type,'source_object_ref',a.object_ref,'actor_ref',btrim(p_actor_ref)));
 return p_decision;
end $$;

create or replace function sourceenergy_one.require_spirit_gate(p_object_type text,p_object_ref uuid) returns boolean language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ begin if not exists(select 1 from sourceenergy_one.spirit_gate_assessments a where a.object_type=p_object_type and a.object_ref=p_object_ref and a.gate_version='spirit-gate-v1' and a.status in ('human_confirmed','exempted')) then raise exception 'Spirit Gate not satisfied for % %',p_object_type,p_object_ref; end if; return true; end $$;

revoke all on function sourceenergy_one.assess_spirit_gate(text,text,uuid,jsonb,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.review_spirit_gate(uuid,text,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.require_spirit_gate(text,uuid) from public,anon,authenticated;
grant execute on function sourceenergy_one.assess_spirit_gate(text,text,uuid,jsonb,text,text) to service_role;
grant execute on function sourceenergy_one.review_spirit_gate(uuid,text,text,text) to service_role;
grant execute on function sourceenergy_one.require_spirit_gate(text,uuid) to service_role;
