create table if not exists wealth_ecology.decision_love_audit_events (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references wealth_ecology.decisions(id) on delete cascade,
  evaluation_id uuid not null references wealth_ecology.decision_love_evaluations(id) on delete restrict,
  event_type text not null,
  actor_ref text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table wealth_ecology.decision_love_audit_events enable row level security;
create policy service_role_full_access_decision_love_audit_events on wealth_ecology.decision_love_audit_events for all to service_role using (true) with check (true);

create or replace function wealth_ecology.block_decision_love_history_mutation() returns trigger language plpgsql set search_path to '' as $$ begin raise exception 'V37.1 decision Love assessment history is append-only; create a superseding assessment instead'; end; $$;
create trigger trg_block_decision_love_history_update before update or delete on wealth_ecology.decision_love_evaluations for each row execute function wealth_ecology.block_decision_love_history_mutation();

revoke insert, update, delete, truncate on wealth_ecology.decision_love_evaluations from service_role;
revoke insert, update, delete, truncate on wealth_ecology.decision_love_audit_events from service_role;
grant select on wealth_ecology.decision_love_evaluations to service_role;
grant select on wealth_ecology.decision_love_audit_events to service_role;

create or replace function wealth_ecology.record_decision_love_assessment_v1(p_decision_id uuid,p_status wealth_ecology.evaluation_status,p_basis text,p_beneficiary_analysis jsonb,p_harm_analysis jsonb,p_self_interest_analysis jsonb,p_uncertainty jsonb,p_evidence_refs jsonb,p_evaluated_by text) returns uuid language plpgsql security definer set search_path to 'wealth_ecology','extensions','pg_temp' as $$
declare v_id uuid; v_prior uuid; v_hash text;
begin
 if not exists(select 1 from wealth_ecology.decisions where id=p_decision_id) then raise exception 'decision not found'; end if;
 if p_status='NOT_APPLICABLE' then raise exception 'Love invariant may not be NOT_APPLICABLE'; end if;
 if nullif(btrim(p_basis),'') is null or nullif(btrim(p_evaluated_by),'') is null then raise exception 'basis and evaluator are required'; end if;
 select id into v_prior from wealth_ecology.decision_love_evaluations where decision_id=p_decision_id and invariant_version='love-invariant-v1' order by created_at desc,id desc limit 1;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('decision_id',p_decision_id,'status',p_status::text,'basis',btrim(p_basis),'beneficiary_analysis',coalesce(p_beneficiary_analysis,'[]'::jsonb),'harm_analysis',coalesce(p_harm_analysis,'[]'::jsonb),'self_interest_analysis',coalesce(p_self_interest_analysis,'{}'::jsonb),'uncertainty',coalesce(p_uncertainty,'{}'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'evaluated_by',btrim(p_evaluated_by),'supersedes',v_prior)::text,'UTF8'),'sha256'),'hex');
 insert into wealth_ecology.decision_love_evaluations(decision_id,status,basis,beneficiary_analysis,harm_analysis,self_interest_analysis,uncertainty,evidence_refs,evaluated_by,evaluated_at,invariant_version,assessment_hash,supersedes_evaluation_id) values(p_decision_id,p_status,btrim(p_basis),coalesce(p_beneficiary_analysis,'[]'::jsonb),coalesce(p_harm_analysis,'[]'::jsonb),coalesce(p_self_interest_analysis,'{}'::jsonb),coalesce(p_uncertainty,'{}'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),btrim(p_evaluated_by),now(),'love-invariant-v1',v_hash,v_prior) returning id into v_id;
 insert into wealth_ecology.decision_love_audit_events(decision_id,evaluation_id,event_type,actor_ref,payload) values(p_decision_id,v_id,'love_assessment_recorded',btrim(p_evaluated_by),jsonb_build_object('status',p_status::text,'assessment_hash',v_hash,'supersedes_evaluation_id',v_prior));
 return v_id;
end; $$;

create or replace function wealth_ecology.review_decision_love_assessment_v1(p_assessment_id uuid,p_final_status wealth_ecology.evaluation_status,p_reviewer_ref text,p_attestation text) returns uuid language plpgsql security definer set search_path to 'wealth_ecology','extensions','pg_temp' as $$
declare a wealth_ecology.decision_love_evaluations%rowtype; v_id uuid; v_hash text;
begin
 if p_final_status not in ('PASS','WARN','FAIL') then raise exception 'final review status must be PASS, WARN, or FAIL'; end if;
 if nullif(btrim(p_reviewer_ref),'') is null or nullif(btrim(p_attestation),'') is null then raise exception 'reviewer and attestation are required'; end if;
 select * into a from wealth_ecology.decision_love_evaluations where id=p_assessment_id;
 if not found then raise exception 'Love assessment not found'; end if;
 if exists(select 1 from wealth_ecology.decision_love_evaluations where supersedes_evaluation_id=a.id) then raise exception 'Love assessment already superseded'; end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('review_of',a.id,'decision_id',a.decision_id,'final_status',p_final_status::text,'basis',a.basis,'beneficiary_analysis',a.beneficiary_analysis,'harm_analysis',a.harm_analysis,'self_interest_analysis',a.self_interest_analysis,'uncertainty',a.uncertainty,'evidence_refs',a.evidence_refs,'reviewer',btrim(p_reviewer_ref),'attestation',btrim(p_attestation))::text,'UTF8'),'sha256'),'hex');
 insert into wealth_ecology.decision_love_evaluations(decision_id,status,basis,beneficiary_analysis,harm_analysis,self_interest_analysis,uncertainty,evidence_refs,evaluated_by,evaluated_at,human_reviewed_by,human_reviewed_at,invariant_version,assessment_hash,supersedes_evaluation_id) values(a.decision_id,p_final_status,a.basis,a.beneficiary_analysis,a.harm_analysis,a.self_interest_analysis,a.uncertainty,a.evidence_refs,a.evaluated_by,a.evaluated_at,btrim(p_reviewer_ref),now(),a.invariant_version,v_hash,a.id) returning id into v_id;
 insert into wealth_ecology.decision_love_audit_events(decision_id,evaluation_id,event_type,actor_ref,payload) values(a.decision_id,v_id,'love_assessment_human_reviewed',btrim(p_reviewer_ref),jsonb_build_object('reviewed_assessment_id',a.id,'final_status',p_final_status::text,'attestation',btrim(p_attestation),'assessment_hash',v_hash));
 return v_id;
end; $$;

grant execute on function wealth_ecology.record_decision_love_assessment_v1(uuid,wealth_ecology.evaluation_status,text,jsonb,jsonb,jsonb,jsonb,jsonb,text) to service_role;
grant execute on function wealth_ecology.review_decision_love_assessment_v1(uuid,wealth_ecology.evaluation_status,text,text) to service_role;
