create table if not exists sourceenergy_one.evidence_intake_envelopes (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 source_class text not null check(source_class in ('institutional_record','research','external_source')),
 external_ref text not null,
 protected_snapshot jsonb not null,
 snapshot_hash text not null check(snapshot_hash ~ '^[0-9a-f]{64}$'),
 provenance_metadata jsonb not null default '{}'::jsonb,
 consent_scope_id text not null,
 actor_ref text not null,
 status text not null default 'captured' check(status in ('captured','spirit_gate_ready','admitted','rejected','withdrawn')),
 admitted_evidence_id uuid unique references sourceenergy_one.evidence_provenance(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(subject_id,source_class,external_ref,snapshot_hash)
);
alter table sourceenergy_one.evidence_intake_envelopes enable row level security;
revoke all on sourceenergy_one.evidence_intake_envelopes from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.evidence_intake_envelopes to service_role;
create policy evidence_intake_envelopes_service_role on sourceenergy_one.evidence_intake_envelopes for all to service_role using(true) with check(true);
create index if not exists evidence_intake_subject_idx on sourceenergy_one.evidence_intake_envelopes(subject_id,created_at desc);

create or replace function sourceenergy_one.create_evidence_intake_envelope(
 p_subject_id text,p_source_class text,p_external_ref text,p_protected_snapshot jsonb,p_provenance_metadata jsonb,p_consent_scope_id text,p_actor_ref text
) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare eid uuid; h text;
begin
 if p_source_class not in ('institutional_record','research','external_source') then raise exception 'invalid external evidence source class'; end if;
 if nullif(btrim(p_subject_id),'') is null or nullif(btrim(p_external_ref),'') is null or nullif(btrim(p_consent_scope_id),'') is null or nullif(btrim(p_actor_ref),'') is null then raise exception 'subject, external ref, consent scope and actor required'; end if;
 if p_protected_snapshot is null or jsonb_typeof(p_protected_snapshot)<>'object' then raise exception 'protected_snapshot must be a JSON object'; end if;
 h:=encode(extensions.digest(convert_to(p_protected_snapshot::text,'UTF8'),'sha256'::text),'hex');
 insert into sourceenergy_one.evidence_intake_envelopes(subject_id,source_class,external_ref,protected_snapshot,snapshot_hash,provenance_metadata,consent_scope_id,actor_ref)
 values(btrim(p_subject_id),p_source_class,btrim(p_external_ref),p_protected_snapshot,h,coalesce(p_provenance_metadata,'{}'::jsonb),btrim(p_consent_scope_id),btrim(p_actor_ref)) returning id into eid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'external_evidence_intake_captured','evidence_intake_envelope',eid::text,jsonb_build_object('source_class',p_source_class,'external_ref',btrim(p_external_ref),'snapshot_hash',h));
 return eid;
end $$;

create or replace function sourceenergy_one.mark_evidence_intake_spirit_gate_ready(p_envelope_id uuid,p_actor_ref text) returns void language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare e sourceenergy_one.evidence_intake_envelopes%rowtype;
begin
 if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
 select * into e from sourceenergy_one.evidence_intake_envelopes where id=p_envelope_id for update; if not found then raise exception 'evidence intake envelope not found'; end if;
 if e.status<>'captured' then raise exception 'evidence intake envelope is not captured'; end if;
 update sourceenergy_one.evidence_intake_envelopes set status='spirit_gate_ready',updated_at=now() where id=e.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),e.subject_id,auth.uid(),'external_evidence_intake_spirit_gate_ready','evidence_intake_envelope',e.id::text,jsonb_build_object('actor_ref',btrim(p_actor_ref)));
end $$;

create or replace function sourceenergy_one.admit_evidence_intake_envelope(p_envelope_id uuid,p_actor_ref text,p_human_attestation text default null) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare e sourceenergy_one.evidence_intake_envelopes%rowtype; gate_id uuid; ev_id uuid;
begin
 if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
 select * into e from sourceenergy_one.evidence_intake_envelopes where id=p_envelope_id for update; if not found then raise exception 'evidence intake envelope not found'; end if;
 if e.status<>'spirit_gate_ready' then raise exception 'evidence intake envelope is not Spirit Gate ready'; end if;
 select a.id into gate_id from sourceenergy_one.spirit_gate_assessments a where a.object_type='evidence_intake_envelope' and a.object_ref=e.id and a.gate_version='spirit-gate-v1' and a.status in ('human_confirmed','exempted') order by a.created_at desc limit 1;
 if gate_id is null then raise exception 'satisfied Spirit Gate assessment required before external evidence admission'; end if;
 insert into sourceenergy_one.evidence_provenance(subject_id,evidence_type,source_object_ref,external_ref,evidence_hash,spirit_gate_assessment_id,consent_scope_id,human_attestation,actor_ref,metadata)
 values(e.subject_id,e.source_class,e.id,e.external_ref,e.snapshot_hash,gate_id,e.consent_scope_id,p_human_attestation,btrim(p_actor_ref),jsonb_build_object('intake_envelope_id',e.id,'provenance_metadata',e.provenance_metadata)) returning id into ev_id;
 update sourceenergy_one.evidence_intake_envelopes set status='admitted',admitted_evidence_id=ev_id,updated_at=now() where id=e.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
 values(gen_random_uuid(),e.subject_id,auth.uid(),'external_evidence_admitted','evidence_provenance',ev_id::text,jsonb_build_object('intake_envelope_id',e.id,'source_class',e.source_class,'spirit_gate_assessment_id',gate_id,'snapshot_hash',e.snapshot_hash));
 return ev_id;
end $$;

create or replace function sourceenergy_one.spirit_gate_object_subject(p_object_type text,p_object_ref uuid) returns text language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare s text; begin case p_object_type when 'living_purpose_journal_entry' then select subject_id into s from sourceenergy_one.living_purpose_journal_entries where id=p_object_ref; when 'knowledge_artifact' then select subject_id into s from sourceenergy_one.knowledge_artifacts where id=p_object_ref; when 'knowledge_insight' then select subject_id into s from sourceenergy_one.knowledge_insights where id=p_object_ref; when 'purpose_reflection_synthesis' then select subject_id into s from sourceenergy_one.purpose_reflection_syntheses where id=p_object_ref; when 'impact_report' then select subject_id into s from sourceenergy_one.impact_reports where id=p_object_ref; when 'genesis_approval' then select ir.subject_id into s from sourceenergy_one.genesis_approvals ga join sourceenergy_one.impact_reports ir on ir.id=ga.impact_report_id where ga.id=p_object_ref; when 'genesis_evolution_nomination' then select subject_id into s from sourceenergy_one.genesis_evolution_nominations where id=p_object_ref; when 'evidence_intake_envelope' then select subject_id into s from sourceenergy_one.evidence_intake_envelopes where id=p_object_ref; else raise exception 'unsupported Spirit Gate object type: %',p_object_type; end case; if s is null then raise exception 'Spirit Gate source object not found'; end if; return s; end $$;

revoke all on function sourceenergy_one.create_evidence_intake_envelope(text,text,text,jsonb,jsonb,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.mark_evidence_intake_spirit_gate_ready(uuid,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.admit_evidence_intake_envelope(uuid,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.create_evidence_intake_envelope(text,text,text,jsonb,jsonb,text,text) to service_role;
grant execute on function sourceenergy_one.mark_evidence_intake_spirit_gate_ready(uuid,text) to service_role;
grant execute on function sourceenergy_one.admit_evidence_intake_envelope(uuid,text,text) to service_role;

revoke execute on function sourceenergy_one.register_external_evidence(text,text,text,text,text,text,text,jsonb) from service_role;
comment on function sourceenergy_one.register_external_evidence(text,text,text,text,text,text,text,jsonb) is 'Deprecated direct external evidence registration. External evidence must use Evidence Intake Envelope -> Spirit Gate -> admission.';
comment on table sourceenergy_one.evidence_intake_envelopes is 'Internalized envelope for external research/institutional/external evidence. Must pass Spirit Gate before typed evidence admission.';
