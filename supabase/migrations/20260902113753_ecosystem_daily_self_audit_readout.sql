-- Leg B of the standing daily audit (audit program, 2026-09-02).
-- Self-contained in-database integrity readout, scheduled via pg_cron.
-- Git-side drift comparison is Leg A's job (Claude scheduled task); this leg
-- records what is measurable from inside the database. Internal state only.

create schema if not exists ecosystem_audit;

create table if not exists ecosystem_audit.daily_readout (
  readout_id uuid primary key default gen_random_uuid(),
  run_at timestamptz not null default now(),
  live_migrations integer not null,
  flagged_fns_unpinned integer not null,           -- S3 regression check (expect 0)
  public_tables_rls_disabled integer not null,     -- tracks S1 exception surface (expect 1: spatial_ref_sys)
  secdef_client_executable integer not null,       -- S2 surface (expect 2 retained setc_media RPCs + 3 st_estimatedextent overloads until platform ticket resolves)
  rls_enabled_no_policy integer not null,          -- default-deny posture size
  exceptions_past_review integer not null,         -- risk-exception clocks breached (expect 0)
  approx_app_rows bigint not null,                 -- population trend
  status text not null check (status in ('GREEN','AMBER','RED')),
  notes text
);

alter table ecosystem_audit.daily_readout enable row level security;
revoke all on schema ecosystem_audit from public, anon, authenticated;
revoke all on ecosystem_audit.daily_readout from public, anon, authenticated;
grant usage on schema ecosystem_audit to service_role;
grant select on ecosystem_audit.daily_readout to service_role;
create policy daily_readout_service_read on ecosystem_audit.daily_readout
  for select to service_role using (true);

create or replace function ecosystem_audit.run_daily_readout()
returns ecosystem_audit.daily_readout
language plpgsql
set search_path = ecosystem_audit, public, pg_catalog
as $fn$
declare
  v_migrations integer;
  v_unpinned integer;
  v_rls_off integer;
  v_secdef integer;
  v_no_policy integer;
  v_past_due integer;
  v_rows bigint;
  v_status text;
  v_notes text := '';
  v_row ecosystem_audit.daily_readout;
begin
  select count(*) into v_migrations from supabase_migrations.schema_migrations;

  select count(*) into v_unpinned
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where (n.nspname, p.proname) in (
    ('ecology','ssr_z_label'),('ecology','ssr_candidate_z_guard'),
    ('ecology','ssr_z_from_egm96_elevation'),('ecology','block_ssr_air_event_audit_mutation'),
    ('ecology','block_ssr_air_delivery_receipt_mutation'),('ecology','ssr_air_policy_matches_event'),
    ('ecology','block_ssr_air_event_decision_mutation'),('ecology','block_ssr_air_event_action_audit_mutation'),
    ('ecology','block_ssr_air_cross_domain_validation_audit_mutation'),('ecology','block_ssr_sea_validation_job_audit_mutation'),
    ('sourcecubes','reconcile_vertical_evidence'))
    and p.proconfig is null;

  select count(*) into v_rls_off
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  select count(distinct p.oid) into v_secdef
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and (has_function_privilege('anon', p.oid, 'execute')
      or has_function_privilege('authenticated', p.oid, 'execute'));

  select count(*) into v_no_policy
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind = 'r' and c.relrowsecurity
    and n.nspname not in ('pg_catalog','information_schema')
    and not exists (select 1 from pg_policy pol where pol.polrelid = c.oid);

  select count(*) into v_past_due
  from dhn_ops.release_risk_exceptions
  where review_due_at < now() and status in ('open','accepted');

  select coalesce(sum(n_live_tup),0) into v_rows
  from pg_stat_user_tables
  where schemaname not in ('auth','storage','realtime','vault','supabase_migrations','net','cron','extensions');

  if v_unpinned > 0 or v_past_due > 0 then
    v_status := 'RED';
    v_notes := trim(v_notes || case when v_unpinned > 0 then 'search_path regression. ' else '' end
                            || case when v_past_due > 0 then v_past_due || ' exception(s) past review clock. ' else '' end);
  elsif v_rls_off > 1 or v_secdef > 5 then
    v_status := 'AMBER';
    v_notes := 'Security surface grew beyond registered baseline (rls_off>1 or secdef>5).';
  else
    v_status := 'GREEN';
  end if;

  insert into ecosystem_audit.daily_readout(
    live_migrations, flagged_fns_unpinned, public_tables_rls_disabled,
    secdef_client_executable, rls_enabled_no_policy, exceptions_past_review,
    approx_app_rows, status, notes)
  values (v_migrations, v_unpinned, v_rls_off, v_secdef, v_no_policy, v_past_due, v_rows, v_status, nullif(v_notes,''))
  returning * into v_row;

  return v_row;
end;
$fn$;

revoke all on function ecosystem_audit.run_daily_readout() from public, anon, authenticated;

-- Schedule daily at 11:00 UTC (~07:00 US Eastern). Re-schedule idempotently.
do $$
begin
  perform cron.unschedule('ecosystem_daily_readout');
exception when others then null;
end $$;
select cron.schedule('ecosystem_daily_readout', '0 11 * * *',
  $$select ecosystem_audit.run_daily_readout();$$);
