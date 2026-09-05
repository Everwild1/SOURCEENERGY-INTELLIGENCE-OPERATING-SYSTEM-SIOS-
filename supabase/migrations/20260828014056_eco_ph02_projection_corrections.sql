create table ecology.projection_corrections (
  id uuid primary key default gen_random_uuid(),
  target_kind text not null check (target_kind in ('object_reference','journey_edge','event_receipt','value_flow_reference','impact_lineage','regenerative_projection')),
  target_key text not null check (btrim(target_key) <> ''),
  correction_type text not null check (correction_type in ('corrects','supersedes','voids_projection')),
  supersedes_correction_id uuid references ecology.projection_corrections(id),
  reason text not null check (btrim(reason) <> ''),
  source_authority text not null check (btrim(source_authority) <> ''),
  authority_reference text,
  evidence_reference text,
  recorded_at timestamptz not null default now(),
  check (authority_reference is null or btrim(authority_reference) <> ''),
  check (evidence_reference is null or btrim(evidence_reference) <> ''),
  check (supersedes_correction_id is null or correction_type = 'supersedes')
);

comment on table ecology.projection_corrections is
  'ECO-PH-02 append-only correction/supersession history for Ecology projections. Records correction lineage without rewriting authoritative source facts.';

alter table ecology.projection_corrections enable row level security;
revoke all on table ecology.projection_corrections from public, anon, authenticated;
grant select, insert on table ecology.projection_corrections to service_role;

create index projection_corrections_target_idx
  on ecology.projection_corrections(target_kind, target_key, recorded_at);
create index projection_corrections_supersedes_idx
  on ecology.projection_corrections(supersedes_correction_id)
  where supersedes_correction_id is not null;
