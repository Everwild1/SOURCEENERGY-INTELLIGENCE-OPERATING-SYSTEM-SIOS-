create table if not exists public.dpot_discernments (
  discernment_id uuid primary key default gen_random_uuid(),
  subject_type text not null,
  subject_ref text not null,
  trace_id text references public.cvi_watchtraces(trace_id) on delete set null,
  assessment_state text not null default 'DRAFT' check (assessment_state in ('DRAFT','REVIEW_REQUIRED','APPROVED','SUPERSEDED')),
  evidence_state text not null default 'NO_EVIDENCE' check (evidence_state in ('NO_EVIDENCE','PARTIAL','CORROBORATED','VERIFIED','CONFLICTED')),
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  finding text not null,
  rationale_summary text,
  evidence_refs jsonb not null default '[]'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_by text,
  reviewed_by text,
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dpot_prophecies (
  prophecy_id uuid primary key default gen_random_uuid(),
  subject_type text not null,
  subject_ref text not null,
  trace_id text references public.cvi_watchtraces(trace_id) on delete set null,
  discernment_id uuid references public.dpot_discernments(discernment_id) on delete set null,
  scenario_label text not null,
  scenario_type text not null check (scenario_type in ('FORECAST','RISK','OPPORTUNITY','TIMING_WINDOW','ALTERNATIVE_PATH')),
  forecast_state text not null default 'DRAFT' check (forecast_state in ('DRAFT','ACTIVE_SCENARIO','RETIRED','OUTCOME_RECORDED')),
  epistemic_status text not null default 'SCENARIO_NOT_FACT' check (epistemic_status = 'SCENARIO_NOT_FACT'),
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  horizon_start timestamptz,
  horizon_end timestamptz,
  projection text not null,
  assumptions jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  outcome_state text check (outcome_state is null or outcome_state in ('UNKNOWN','CONSISTENT','PARTIAL','INCONSISTENT')),
  outcome_notes text,
  created_by text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (horizon_end is null or horizon_start is null or horizon_end >= horizon_start)
);

create table if not exists public.dpot_open_scroll_sessions (
  session_id uuid primary key default gen_random_uuid(),
  subject_type text not null,
  subject_ref text not null,
  trace_id text references public.cvi_watchtraces(trace_id) on delete set null,
  opened_by text,
  purpose text,
  requested_scope jsonb not null default '{}'::jsonb,
  snapshot_state text not null default 'ASSEMBLING' check (snapshot_state in ('ASSEMBLING','OPEN','CLOSED','BLOCKED')),
  evidence_cutoff_at timestamptz not null default now(),
  snapshot jsonb not null default '{}'::jsonb,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  check (closed_at is null or closed_at >= opened_at)
);

create table if not exists public.dpot_trace_runs (
  trace_run_id uuid primary key default gen_random_uuid(),
  root_subject_type text not null,
  root_subject_ref text not null,
  trace_id text references public.cvi_watchtraces(trace_id) on delete set null,
  mode text not null default 'FULL' check (mode in ('ORIGIN','RELATIONSHIP','EVIDENCE','TEMPORAL','OUTCOME','FULL')),
  run_state text not null default 'QUEUED' check (run_state in ('QUEUED','RUNNING','COMPLETE','PARTIAL','BLOCKED','FAILED')),
  max_depth smallint not null default 6 check (max_depth between 0 and 32),
  visited_node_count integer not null default 0 check (visited_node_count >= 0),
  cycle_count integer not null default 0 check (cycle_count >= 0),
  evidence_cutoff_at timestamptz not null default now(),
  requested_by text,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (completed_at is null or started_at is null or completed_at >= started_at)
);

create table if not exists public.dpot_trace_nodes (
  node_id uuid primary key default gen_random_uuid(),
  trace_run_id uuid not null references public.dpot_trace_runs(trace_run_id) on delete cascade,
  node_type text not null,
  node_ref text not null,
  node_label text,
  depth smallint not null default 0 check (depth between 0 and 32),
  verification_state text not null default 'UNOBSERVED' check (verification_state in ('UNOBSERVED','REGISTERED','OBSERVED','CORROBORATED','VERIFIED','CONFLICTED','BLOCKED')),
  evidence_summary jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  discovered_at timestamptz not null default now(),
  unique (trace_run_id, node_type, node_ref)
);

create table if not exists public.dpot_trace_edges (
  edge_id uuid primary key default gen_random_uuid(),
  trace_run_id uuid not null references public.dpot_trace_runs(trace_run_id) on delete cascade,
  from_node_id uuid not null references public.dpot_trace_nodes(node_id) on delete cascade,
  to_node_id uuid not null references public.dpot_trace_nodes(node_id) on delete cascade,
  relationship_type text not null,
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  evidence_refs jsonb not null default '[]'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (from_node_id <> to_node_id),
  unique (trace_run_id, from_node_id, to_node_id, relationship_type)
);

create table if not exists public.dpot_trace_evidence_links (
  link_id uuid primary key default gen_random_uuid(),
  trace_run_id uuid not null references public.dpot_trace_runs(trace_run_id) on delete cascade,
  node_id uuid references public.dpot_trace_nodes(node_id) on delete cascade,
  cvi_evidence_id uuid references public.cvi_evidence_events(evidence_id) on delete set null,
  evidence_role text not null check (evidence_role in ('SUPPORTS','CORROBORATES','CONFLICTS','CONTEXT')),
  note text,
  created_at timestamptz not null default now(),
  check (node_id is not null or cvi_evidence_id is not null)
);

create index if not exists dpot_discernments_trace_id_idx on public.dpot_discernments(trace_id);
create index if not exists dpot_discernments_subject_idx on public.dpot_discernments(subject_type, subject_ref);
create index if not exists dpot_prophecies_trace_id_idx on public.dpot_prophecies(trace_id);
create index if not exists dpot_prophecies_discernment_id_idx on public.dpot_prophecies(discernment_id);
create index if not exists dpot_prophecies_subject_idx on public.dpot_prophecies(subject_type, subject_ref);
create index if not exists dpot_open_scroll_trace_id_idx on public.dpot_open_scroll_sessions(trace_id);
create index if not exists dpot_open_scroll_subject_idx on public.dpot_open_scroll_sessions(subject_type, subject_ref);
create index if not exists dpot_trace_runs_trace_id_idx on public.dpot_trace_runs(trace_id);
create index if not exists dpot_trace_runs_root_idx on public.dpot_trace_runs(root_subject_type, root_subject_ref);
create index if not exists dpot_trace_nodes_run_depth_idx on public.dpot_trace_nodes(trace_run_id, depth);
create index if not exists dpot_trace_edges_run_idx on public.dpot_trace_edges(trace_run_id);
create index if not exists dpot_trace_edges_from_idx on public.dpot_trace_edges(from_node_id);
create index if not exists dpot_trace_edges_to_idx on public.dpot_trace_edges(to_node_id);
create index if not exists dpot_trace_evidence_run_idx on public.dpot_trace_evidence_links(trace_run_id);
create index if not exists dpot_trace_evidence_node_idx on public.dpot_trace_evidence_links(node_id);
create index if not exists dpot_trace_evidence_cvi_idx on public.dpot_trace_evidence_links(cvi_evidence_id);

alter table public.dpot_discernments enable row level security;
alter table public.dpot_prophecies enable row level security;
alter table public.dpot_open_scroll_sessions enable row level security;
alter table public.dpot_trace_runs enable row level security;
alter table public.dpot_trace_nodes enable row level security;
alter table public.dpot_trace_edges enable row level security;
alter table public.dpot_trace_evidence_links enable row level security;

revoke all on table public.dpot_discernments from anon, authenticated, public;
revoke all on table public.dpot_prophecies from anon, authenticated, public;
revoke all on table public.dpot_open_scroll_sessions from anon, authenticated, public;
revoke all on table public.dpot_trace_runs from anon, authenticated, public;
revoke all on table public.dpot_trace_nodes from anon, authenticated, public;
revoke all on table public.dpot_trace_edges from anon, authenticated, public;
revoke all on table public.dpot_trace_evidence_links from anon, authenticated, public;

grant select, insert, update, delete on table public.dpot_discernments to service_role;
grant select, insert, update, delete on table public.dpot_prophecies to service_role;
grant select, insert, update, delete on table public.dpot_open_scroll_sessions to service_role;
grant select, insert, update, delete on table public.dpot_trace_runs to service_role;
grant select, insert, update, delete on table public.dpot_trace_nodes to service_role;
grant select, insert, update, delete on table public.dpot_trace_edges to service_role;
grant select, insert, update, delete on table public.dpot_trace_evidence_links to service_role;

create policy "service role manages dpot discernments" on public.dpot_discernments for all to service_role using (true) with check (true);
create policy "service role manages dpot prophecies" on public.dpot_prophecies for all to service_role using (true) with check (true);
create policy "service role manages dpot open scroll sessions" on public.dpot_open_scroll_sessions for all to service_role using (true) with check (true);
create policy "service role manages dpot trace runs" on public.dpot_trace_runs for all to service_role using (true) with check (true);
create policy "service role manages dpot trace nodes" on public.dpot_trace_nodes for all to service_role using (true) with check (true);
create policy "service role manages dpot trace edges" on public.dpot_trace_edges for all to service_role using (true) with check (true);
create policy "service role manages dpot evidence links" on public.dpot_trace_evidence_links for all to service_role using (true) with check (true);

create or replace view public.dpot_live_status
with (security_invoker = true)
as
select
  (select count(*) from public.dpot_discernments) as discernment_count,
  (select count(*) from public.dpot_prophecies) as prophecy_scenario_count,
  (select count(*) from public.dpot_open_scroll_sessions where snapshot_state in ('ASSEMBLING','OPEN')) as open_scroll_count,
  (select count(*) from public.dpot_trace_runs) as trace_run_count,
  (select count(*) from public.dpot_trace_runs where run_state in ('QUEUED','RUNNING')) as active_trace_run_count,
  (select count(*) from public.dpot_trace_nodes) as trace_node_count,
  (select count(*) from public.dpot_trace_edges) as trace_edge_count,
  (select count(*) from public.dpot_trace_evidence_links) as evidence_link_count;

revoke all on table public.dpot_live_status from anon, authenticated, public;
grant select on table public.dpot_live_status to service_role;

comment on table public.dpot_discernments is 'Governed discernment records: findings must preserve evidence state, provenance, review status and calibrated confidence. Rationale is a concise reviewable summary, not private chain-of-thought.';
comment on table public.dpot_prophecies is 'Forward-looking scenario intelligence. Every row is explicitly SCENARIO_NOT_FACT and must never be presented as independently verified fact or guaranteed future outcome.';
comment on table public.dpot_open_scroll_sessions is 'Governed Open Scroll session snapshots assembled from authorized references as of an evidence cutoff time.';
comment on table public.dpot_trace_runs is 'Deep-Dive Trace execution registry supporting origin, relationship, evidence, temporal, outcome and full graph traversal with bounded recursion.';
comment on table public.dpot_trace_nodes is 'Trace graph nodes. Unique run/type/reference keys provide deterministic visited-node control and limit recursive cycles.';
comment on table public.dpot_trace_evidence_links is 'Links DPOT trace results to CVI evidence records. Store references and metadata only; do not store credentials, private keys, full banking messages or account secrets.';

update public.cvi_interface_config
set version_label='Tier III+ — DPOT Evidence-Governed Intelligence',
    operational_definition='LIVE means the SourceEnergy command backend is reachable and the CVI/DPOT control plane is recording evidence-backed runtime state. DISCERN separates evidence from inference; PROPHESY stores scenario intelligence only and never converts a forecast into fact; OPEN SCROLL assembles governed records at an evidence cutoff; DEEP-DIVE TRACE traverses bounded provenance, relationship, evidence, temporal and outcome graphs. Governance declarations remain separate from independent technical verification.',
    updated_at=now()
where config_key='primary';