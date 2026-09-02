create table if not exists ecology.ssr_air_time_correction_audit (
  id bigserial primary key,
  correction_batch_id uuid not null,
  old_profile_id uuid not null references ecology.ssr_air_profiles(id) on delete restrict,
  replacement_profile_id uuid references ecology.ssr_air_profiles(id) on delete restrict,
  old_dataset_name text not null,
  replacement_dataset_name text,
  recorded_evidence_time timestamptz not null,
  decoded_provider_time timestamptz,
  intended_target_time timestamptz,
  correction_reason text not null,
  correction_mode text not null default 'SUPERSEDED_BY_PINNED_CYCLE_RETRIEVAL',
  correction_payload jsonb not null default '{}'::jsonb,
  physical_impact_asserted boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  recorded_at timestamptz not null default now(),
  unique(old_profile_id),
  check(physical_impact_asserted=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create table if not exists ecology.ssr_monitoring_checkpoint_evidence_audit (
  id bigserial primary key,
  correction_batch_id uuid not null,
  checkpoint_id uuid not null references ecology.ssr_environmental_monitoring_checkpoints(id) on delete restrict,
  old_air_profile_id uuid references ecology.ssr_air_profiles(id) on delete restrict,
  new_air_profile_id uuid not null references ecology.ssr_air_profiles(id) on delete restrict,
  scheduled_time timestamptz not null,
  old_quality_gate text,
  new_quality_gate text not null,
  correction_reason text not null,
  correction_payload jsonb not null default '{}'::jsonb,
  physical_impact_asserted boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  recorded_at timestamptz not null default now(),
  unique(checkpoint_id,new_air_profile_id),
  check(physical_impact_asserted=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create table if not exists ecology.ssr_air_event_source_corrections (
  id bigserial primary key,
  correction_batch_id uuid not null,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  old_profile_id uuid not null references ecology.ssr_air_profiles(id) on delete restrict,
  new_profile_id uuid not null references ecology.ssr_air_profiles(id) on delete restrict,
  old_event_fingerprint text not null,
  new_event_fingerprint text not null,
  old_dataset_name text not null,
  new_dataset_name text not null,
  correction_reason text not null,
  corrected_candidate_snapshot jsonb not null,
  event_classification_preserved boolean not null,
  physical_impact_asserted boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  recorded_at timestamptz not null default now(),
  unique(event_id,new_profile_id),
  check(physical_impact_asserted=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create or replace function ecology.block_ssr_time_lineage_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'scientific time-lineage audit tables are append-only';
end $$;

do $$
declare r record;
begin
  for r in select unnest(array[
    'ssr_air_time_correction_audit',
    'ssr_monitoring_checkpoint_evidence_audit',
    'ssr_air_event_source_corrections'
  ]) as table_name
  loop
    execute format('alter table ecology.%I enable row level security',r.table_name);
    execute format('drop policy if exists %I on ecology.%I',r.table_name||'_service_role_select',r.table_name);
    execute format('create policy %I on ecology.%I for select to service_role using(true)',r.table_name||'_service_role_select',r.table_name);
    execute format('revoke all on ecology.%I from anon,authenticated',r.table_name);
    execute format('grant select on ecology.%I to service_role',r.table_name);
    execute format('drop trigger if exists %I on ecology.%I','trg_block_'||r.table_name||'_mutation',r.table_name);
    execute format('create trigger %I before update or delete on ecology.%I for each row execute function ecology.block_ssr_time_lineage_audit_mutation()','trg_block_'||r.table_name||'_mutation',r.table_name);
  end loop;
end $$;

create index if not exists ix_ssr_air_time_correction_batch on ecology.ssr_air_time_correction_audit(correction_batch_id,recorded_at);
create index if not exists ix_ssr_checkpoint_evidence_audit_batch on ecology.ssr_monitoring_checkpoint_evidence_audit(correction_batch_id,scheduled_time);
create index if not exists ix_ssr_event_source_correction_batch on ecology.ssr_air_event_source_corrections(correction_batch_id,event_id);

comment on table ecology.ssr_air_time_correction_audit is 'Append-only scientific time-coordinate correction lineage. Superseded profiles are preserved and excluded from current analytics; no canonical SSR identity authority is created.';
comment on table ecology.ssr_monitoring_checkpoint_evidence_audit is 'Append-only lineage for replacing monitoring checkpoint AIR evidence with exact pinned-cycle profiles.';
comment on table ecology.ssr_air_event_source_corrections is 'Append-only event source rebasing lineage when corrected scientific evidence preserves or changes an existing event classification.';
