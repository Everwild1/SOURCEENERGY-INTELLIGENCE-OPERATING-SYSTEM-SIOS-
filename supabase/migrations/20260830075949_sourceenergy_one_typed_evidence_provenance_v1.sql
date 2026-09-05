create table if not exists sourceenergy_one.evidence_provenance (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 evidence_type text not null check(evidence_type in ('journal_entry','knowledge_artifact','knowledge_insight','purpose_reflection','impact_report','institutional_record','research','external_source','genesis_package')),
 source_object_ref uuid,
 external_ref text,
 evidence_hash text not null check(evidence_hash ~ '^[0-9a-f]{64}$'),
 spirit_gate_assessment_id uuid references sourceenergy_one.spirit_gate_assessments(id),
 consent_scope_id text not null,
 seci_cycle_id uuid references sourceenergy_one.knowledge_cycles(id),
 codex24_version text,
 human_attestation text,
 actor_ref text not null,
 metadata jsonb not null default '{}'::jsonb,
 status text not null default 'active' check(status in ('active','withdrawn','superseded')),
 created_at timestamptz not null default now(),
 constraint evidence_provenance_source_ck check(source_object_ref is not null or nullif(btrim(external_ref),'') is not null)
);

alter table sourceenergy_one.evidence_provenance enable row level security;
revoke all on sourceenergy_one.evidence_provenance from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.evidence_provenance to service_role;
create policy evidence_provenance_service_role on sourceenergy_one.evidence_provenance for all to service_role using(true) with check(true);
create unique index if not exists evidence_provenance_internal_unique_idx on sourceenergy_one.evidence_provenance(evidence_type,source_object_ref,evidence_hash) where source_object_ref is not null;
create index if not exists evidence_provenance_subject_idx on sourceenergy_one.evidence_provenance(subject_id,created_at desc);

create or replace function sourceenergy_one.resolve_evidence_object(p_evidence_type text,p_source_object_ref uuid) returns table(subject_id text,evidence_hash text,consent_scope_id text,seci_cycle_id uuid,codex24_version text) language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ begin
 if p_source_object_ref is null then raise exception 'source_object_ref required'; end if;
 case p_evidence_type
  when 'journal_entry' then return query select e.subject_id,e.content_hash,e.consent_scope_id,null::uuid,null::text from sourceenergy_one.living_purpose_journal_entries e where e.id=p_source_object_ref and e.status='active';
  when 'knowledge_artifact' then return query select a.subject_id,a.content_hash,a.consent_scope_id,a.cycle_id,null::text from sourceenergy_one.knowledge_artifacts a where a.id=p_source_object_ref;
  when 'knowledge_insight' then return query select k.subject_id,encode(extensions.digest(convert_to(k.insight::text,'UTF8'),'sha256'::text),'hex'),k.consent_scope_id,k.cycle_id,k.codex24_version from sourceenergy_one.knowledge_insights k where k.id=p_source_object_ref;
  when 'purpose_reflection' then return query select r.subject_id,encode(extensions.digest(convert_to((jsonb_build_object('signals_4p',r.signals_4p,'proposed_changes',r.proposed_changes,'materiality',r.materiality))::text,'UTF8'),'sha256'::text),'hex'),r.consent_scope_id,null::uuid,r.synthesis_version from sourceenergy_one.purpose_reflection_syntheses r where r.id=p_source_object_ref;
  when 'impact_report' then return query select i.subject_id,encode(extensions.digest(convert_to((jsonb_build_object('mission',i.mission,'vision',i.vision,'purpose',i.purpose,'impact_thesis',i.impact_thesis,'impact_horizons',i.impact_horizons))::text,'UTF8'),'sha256'::text),'hex'),coalesce((select ga.consent_receipt_id from sourceenergy_one.genesis_approvals ga where ga.impact_report_id=i.id and ga.decision='approve' order by ga.decided_at desc limit 1),'impact-report'),null::uuid,null::text from sourceenergy_one.impact_reports i where i.id=p_source_object_ref;
  when 'genesis_package' then return query select g.subject_id,g.package_content_hash,coalesce((select ga.consent_receipt_id from sourceenergy_one.genesis_approvals ga where ga.id=g.approval_id),'genesis'),null::uuid,g.package->>'codex24_package_version' from sourceenergy_one.genesis_packages g where g.id=p_source_object_ref;
  else raise exception 'unsupported internal evidence type: %',p_evidence_type;
 end case;
 if not found then raise exception 'evidence source object not found or inactive'; end if;
end $$;

create or replace function sourceenergy_one.register_internal_evidence(
 p_evidence_type text,p_source_object_ref uuid,p_actor_ref text,p_human_attestation text default null,p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare s text; h text; c text; cyc uuid; cv text; gate_id uuid; eid uuid; begin
 if p_evidence_type not in ('journal_entry','knowledge_artifact','knowledge_insight','purpose_reflection','impact_report','genesis_package') then raise exception 'unsupported internal evidence type'; end if;
 if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
 select subject_id,evidence_hash,consent_scope_id,seci_cycle_id,codex24_version into s,h,c,cyc,cv from sourceenergy_one.resolve_evidence_object(p_evidence_type,p_source_object_ref);
 select a.id into gate_id from sourceenergy_one.spirit_gate_assessments a where a.object_ref=p_source_object_ref and a.status in ('human_confirmed','exempted') order by a.created_at desc limit 1;
 if gate_id is null then raise exception 'satisfied Spirit Gate assessment required before evidence registration'; end if;
 insert into sourceenergy_one.evidence_provenance(subject_id,evidence_type,source_object_ref,evidence_hash,spirit_gate_assessment_id,consent_scope_id,seci_cycle_id,codex24_version,human_attestation,actor_ref,metadata)
 values(s,p_evidence_type,p_source_object_ref,h,gate_id,c,cyc,cv,p_human_attestation,btrim(p_actor_ref),coalesce(p_metadata,'{}'::jsonb)) returning id into eid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),s,auth.uid(),'typed_evidence_registered','evidence_provenance',eid::text,jsonb_build_object('evidence_type',p_evidence_type,'source_object_ref',p_source_object_ref,'evidence_hash',h,'spirit_gate_assessment_id',gate_id));
 return eid;
end $$;

create or replace function sourceenergy_one.register_external_evidence(
 p_subject_id text,p_evidence_type text,p_external_ref text,p_evidence_hash text,p_consent_scope_id text,p_actor_ref text,p_human_attestation text default null,p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare eid uuid; begin
 if p_evidence_type not in ('institutional_record','research','external_source') then raise exception 'unsupported external evidence type'; end if;
 if nullif(btrim(p_subject_id),'') is null or nullif(btrim(p_external_ref),'') is null or nullif(btrim(p_consent_scope_id),'') is null or nullif(btrim(p_actor_ref),'') is null then raise exception 'subject, external_ref, consent scope and actor required'; end if;
 if p_evidence_hash !~ '^[0-9a-f]{64}$' then raise exception 'evidence hash must be 64 lowercase hex characters'; end if;
 insert into sourceenergy_one.evidence_provenance(subject_id,evidence_type,external_ref,evidence_hash,consent_scope_id,human_attestation,actor_ref,metadata)
 values(btrim(p_subject_id),p_evidence_type,btrim(p_external_ref),p_evidence_hash,btrim(p_consent_scope_id),p_human_attestation,btrim(p_actor_ref),coalesce(p_metadata,'{}'::jsonb)) returning id into eid;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),btrim(p_subject_id),auth.uid(),'external_evidence_registered','evidence_provenance',eid::text,jsonb_build_object('evidence_type',p_evidence_type,'external_ref',btrim(p_external_ref),'evidence_hash',p_evidence_hash));
 return eid;
end $$;

create or replace function sourceenergy_one.require_evidence_provenance(p_evidence_id uuid,p_subject_id text default null) returns boolean language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare e sourceenergy_one.evidence_provenance%rowtype; begin select * into e from sourceenergy_one.evidence_provenance where id=p_evidence_id and status='active'; if not found then raise exception 'active typed evidence provenance required'; end if; if p_subject_id is not null and e.subject_id<>p_subject_id then raise exception 'evidence subject mismatch'; end if; if e.source_object_ref is not null and e.spirit_gate_assessment_id is null then raise exception 'internal evidence missing Spirit Gate assessment'; end if; return true; end $$;

revoke all on function sourceenergy_one.resolve_evidence_object(text,uuid) from public,anon,authenticated;
revoke all on function sourceenergy_one.register_internal_evidence(text,uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function sourceenergy_one.register_external_evidence(text,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function sourceenergy_one.require_evidence_provenance(uuid,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.resolve_evidence_object(text,uuid) to service_role;
grant execute on function sourceenergy_one.register_internal_evidence(text,uuid,text,text,jsonb) to service_role;
grant execute on function sourceenergy_one.register_external_evidence(text,text,text,text,text,text,text,jsonb) to service_role;
grant execute on function sourceenergy_one.require_evidence_provenance(uuid,text) to service_role;

comment on table sourceenergy_one.evidence_provenance is 'Typed evidence registry linking evidence kind, content hash, Spirit Gate assessment, consent, SECI provenance, Codex24 provenance and human attestation.';
