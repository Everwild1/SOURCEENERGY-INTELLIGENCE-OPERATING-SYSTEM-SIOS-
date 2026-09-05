-- WE-15: Wealth Ecology service-only access hardening
-- Mirrors authoritative SourceEnergy-command-backend migration.

revoke all on schema wealth_ecology from anon, authenticated;
grant usage on schema wealth_ecology to service_role;

revoke all privileges on all tables in schema wealth_ecology from anon, authenticated;
revoke all privileges on all sequences in schema wealth_ecology from anon, authenticated;
revoke execute on all functions in schema wealth_ecology from anon, authenticated, public;

grant all privileges on all tables in schema wealth_ecology to service_role;
grant all privileges on all sequences in schema wealth_ecology to service_role;
grant execute on all functions in schema wealth_ecology to service_role;

alter default privileges for role postgres in schema wealth_ecology
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema wealth_ecology
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema wealth_ecology
  revoke execute on functions from anon, authenticated, public;
alter default privileges for role postgres in schema wealth_ecology
  grant all on tables to service_role;
alter default privileges for role postgres in schema wealth_ecology
  grant all on sequences to service_role;
alter default privileges for role postgres in schema wealth_ecology
  grant execute on functions to service_role;

do $$
declare
  r record;
  policy_name text;
begin
  for r in
    select c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'wealth_ecology'
      and c.relkind in ('r','p')
  loop
    execute format('alter table wealth_ecology.%I enable row level security', r.table_name);
    policy_name := 'service_role_full_access_' || r.table_name;
    if not exists (
      select 1 from pg_policies
      where schemaname = 'wealth_ecology'
        and tablename = r.table_name
        and policyname = policy_name
    ) then
      execute format(
        'create policy %I on wealth_ecology.%I for all to service_role using (true) with check (true)',
        policy_name,
        r.table_name
      );
    end if;
  end loop;
end
$$;
