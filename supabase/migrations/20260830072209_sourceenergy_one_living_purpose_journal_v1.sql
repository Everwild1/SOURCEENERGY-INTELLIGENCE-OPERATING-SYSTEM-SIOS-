create table if not exists sourceenergy_one.living_purpose_journal_entries (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 recorded_at timestamptz not null default now(),
 effective_at timestamptz,
 protected_content jsonb not null,
 content_hash text not null,
 consent_scope_id text not null,
 visibility text not null default 'private' check (visibility in ('private','reflection_only','approved_derived_use')),
 source_type text not null default 'journal',
 prior_entry_id uuid references sourceenergy_one.living_purpose_journal_entries(id),
 actor_ref text not null,
 status text not null default 'active' check (status in ('active','withdrawn','superseded')),
 created_at timestamptz not null default now(),
 constraint living_purpose_journal_hash_ck check (content_hash ~ '^[0-9a-f]{64}$')
);

create table if not exists sourceenergy_one.purpose_reflection_syntheses (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 source_entry_ids uuid[] not null,
 source_hashes text[] not null,
 synthesis_version text not null,
 model_provenance jsonb not null default '{}'::jsonb,
 signals_4p jsonb not null,
 materiality text not null check (materiality in ('none','minor','material')),
 proposed_changes jsonb not null default '{}'::jsonb,
 consent_scope_id text not null,
 human_review_status text not null default 'pending' check (human_review_status in ('pending','confirmed','rejected','revision_requested')),
 reviewed_by_actor_ref text,
 reviewed_at timestamptz,
 review_attestation text,
 created_at timestamptz not null default now(),
 constraint purpose_reflection_sources_nonempty_ck check (cardinality(source_entry_ids)>0 and cardinality(source_entry_ids)=cardinality(source_hashes))
);

alter table sourceenergy_one.living_purpose_journal_entries enable row level security;
alter table sourceenergy_one.purpose_reflection_syntheses enable row level security;
revoke all on sourceenergy_one.living_purpose_journal_entries from public,anon,authenticated;
revoke all on sourceenergy_one.purpose_reflection_syntheses from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.living_purpose_journal_entries to service_role;
grant select,insert,update on sourceenergy_one.purpose_reflection_syntheses to service_role;

create policy living_purpose_journal_service_role on sourceenergy_one.living_purpose_journal_entries for all to service_role using (true) with check (true);
create policy purpose_reflection_service_role on sourceenergy_one.purpose_reflection_syntheses for all to service_role using (true) with check (true);

create index if not exists living_purpose_journal_subject_time_idx on sourceenergy_one.living_purpose_journal_entries(subject_id,recorded_at desc);
create index if not exists purpose_reflection_subject_time_idx on sourceenergy_one.purpose_reflection_syntheses(subject_id,created_at desc);

comment on table sourceenergy_one.living_purpose_journal_entries is 'Private longitudinal lived-experience source record. Raw narrative is not Genesis, SETC, SourceCube, or execution authority.';
comment on table sourceenergy_one.purpose_reflection_syntheses is 'Derived Codex24/SourceEnergy One reflection artifacts. AI synthesis is counsel; material 4P evolution requires human confirmation.';
