create table if not exists dhn_ops.acceptance_test_runs (
  test_run_id uuid primary key default gen_random_uuid(), suite_version text not null default 'dhn-e11-v1', environment text not null default 'production',
  status text not null default 'running' check (status in ('running','passed','failed','blocked')), release_decision text check (release_decision in ('go','no_go','conditional_go')),
  summary jsonb not null default '{}'::jsonb, started_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists dhn_ops.acceptance_test_results (
  test_result_id uuid primary key default gen_random_uuid(), test_run_id uuid not null references dhn_ops.acceptance_test_runs(test_run_id) on delete cascade,
  test_code text not null, test_domain text not null, test_type text not null check (test_type in ('positive','negative','security','integrity','operational','release')),
  status text not null check (status in ('pass','fail','blocked','not_run')), expected_outcome text not null, observed_outcome text not null,
  evidence jsonb not null default '{}'::jsonb, executed_at timestamptz not null default now(), unique(test_run_id,test_code)
);
create index if not exists idx_dhn_e11_results_run on dhn_ops.acceptance_test_results(test_run_id);
create index if not exists idx_dhn_e11_results_status on dhn_ops.acceptance_test_results(status,test_domain);
alter table dhn_ops.acceptance_test_runs enable row level security;
alter table dhn_ops.acceptance_test_results enable row level security;
revoke all privileges on dhn_ops.acceptance_test_runs,dhn_ops.acceptance_test_results from public,anon,authenticated;
grant all privileges on dhn_ops.acceptance_test_runs,dhn_ops.acceptance_test_results to service_role;
create policy e11_runs_service_role on dhn_ops.acceptance_test_runs for all to service_role using (true) with check (true);
create policy e11_results_service_role on dhn_ops.acceptance_test_results for all to service_role using (true) with check (true);
comment on table dhn_ops.acceptance_test_runs is 'DHH E11 release-readiness test runs; operational evidence only, no PHI or raw biometric/telemetry material.';
comment on table dhn_ops.acceptance_test_results is 'DHH E11 test evidence. Evidence must remain privacy-minimized and non-clinical.';
