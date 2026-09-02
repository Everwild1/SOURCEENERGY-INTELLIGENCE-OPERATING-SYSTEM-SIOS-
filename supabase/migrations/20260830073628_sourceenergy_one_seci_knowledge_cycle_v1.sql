create table if not exists sourceenergy_one.knowledge_cycles (
 id uuid primary key default gen_random_uuid(), subject_id text not null,
 title text, context jsonb not null default '{}'::jsonb,
 consent_scope_id text not null, current_phase text not null default 'socialize' check(current_phase in ('socialize','externalize','combine','internalize')),
 status text not null default 'active' check(status in ('active','completed','withdrawn')),
 prior_cycle_id uuid references sourceenergy_one.knowledge_cycles(id), actor_ref text not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists sourceenergy_one.knowledge_artifacts (
 id uuid primary key default gen_random_uuid(), cycle_id uuid not null references sourceenergy_one.knowledge_cycles(id), subject_id text not null,
 phase text not null check(phase in ('socialize','externalize','combine','internalize')), artifact_type text not null,
 protected_content jsonb not null, content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
 consent_scope_id text not null, visibility text not null default 'private' check(visibility in ('private','cycle_only','reflection_only','approved_derived_use')),
 source_refs jsonb not null default '[]'::jsonb, actor_ref text not null, created_at timestamptz not null default now()
);
create table if not exists sourceenergy_one.knowledge_transitions (
 id uuid primary key default gen_random_uuid(), cycle_id uuid not null references sourceenergy_one.knowledge_cycles(id), subject_id text not null,
 from_phase text not null check(from_phase in ('socialize','externalize','combine','internalize')), to_phase text not null check(to_phase in ('socialize','externalize','combine','internalize')),
 evidence_artifact_ids uuid[] not null, rationale text not null, actor_ref text not null, created_at timestamptz not null default now(),
 constraint knowledge_transition_evidence_ck check(cardinality(evidence_artifact_ids)>0)
);
create table if not exists sourceenergy_one.knowledge_insights (
 id uuid primary key default gen_random_uuid(), cycle_id uuid not null references sourceenergy_one.knowledge_cycles(id), subject_id text not null,
 source_artifact_ids uuid[] not null, source_hashes text[] not null, codex24_version text not null,
 insight jsonb not null, related_4p_dimensions text[] not null default '{}'::text[], materiality text not null default 'none' check(materiality in ('none','minor','material')),
 authority_status text not null default 'counsel' check(authority_status in ('counsel','human_confirmed','rejected')),
 consent_scope_id text not null, reviewed_by_actor_ref text, reviewed_at timestamptz, review_attestation text, created_at timestamptz not null default now(),
 constraint knowledge_insight_sources_ck check(cardinality(source_artifact_ids)>0 and cardinality(source_artifact_ids)=cardinality(source_hashes)),
 constraint knowledge_insight_4p_ck check(related_4p_dimensions <@ array['purpose','product','people','profit']::text[])
);

alter table sourceenergy_one.knowledge_cycles enable row level security; alter table sourceenergy_one.knowledge_artifacts enable row level security; alter table sourceenergy_one.knowledge_transitions enable row level security; alter table sourceenergy_one.knowledge_insights enable row level security;
revoke all on sourceenergy_one.knowledge_cycles,sourceenergy_one.knowledge_artifacts,sourceenergy_one.knowledge_transitions,sourceenergy_one.knowledge_insights from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.knowledge_cycles,sourceenergy_one.knowledge_artifacts,sourceenergy_one.knowledge_transitions,sourceenergy_one.knowledge_insights to service_role;
create policy knowledge_cycles_service_role on sourceenergy_one.knowledge_cycles for all to service_role using(true) with check(true);
create policy knowledge_artifacts_service_role on sourceenergy_one.knowledge_artifacts for all to service_role using(true) with check(true);
create policy knowledge_transitions_service_role on sourceenergy_one.knowledge_transitions for all to service_role using(true) with check(true);
create policy knowledge_insights_service_role on sourceenergy_one.knowledge_insights for all to service_role using(true) with check(true);
create index if not exists knowledge_cycles_subject_idx on sourceenergy_one.knowledge_cycles(subject_id,created_at desc);
create index if not exists knowledge_artifacts_cycle_idx on sourceenergy_one.knowledge_artifacts(cycle_id,created_at);
create index if not exists knowledge_insights_cycle_idx on sourceenergy_one.knowledge_insights(cycle_id,created_at);
comment on table sourceenergy_one.knowledge_cycles is 'Governed SECI knowledge spiral: Socialize -> Externalize -> Combine -> Internalize -> next Socialize.';
comment on table sourceenergy_one.knowledge_insights is 'Codex24/AI knowledge counsel. No insight is authoritative or consequential solely because it was generated.';
