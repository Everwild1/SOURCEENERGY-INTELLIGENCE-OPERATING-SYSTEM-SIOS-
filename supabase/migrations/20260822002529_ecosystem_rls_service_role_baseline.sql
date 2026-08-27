-- Ecosystem security baseline.
-- Adds a service_role-only policy to RLS-enabled tables that currently have no
-- policies. This is intentionally additive: it does not grant anon or
-- authenticated access and does not alter tables that already have policies.

do $$
declare
  r record;
  policy_name text := 'service_role_all';
begin
  for r in
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'r'
      and c.relrowsecurity = true
      and n.nspname in ('cruds','geniza','migration_transport','public','wim')
      and not exists (
        select 1
        from pg_policy p
        where p.polrelid = c.oid
      )
  loop
    execute format(
      'create policy %I on %I.%I for all to service_role using (true) with check (true)',
      policy_name,
      r.schema_name,
      r.table_name
    );
  end loop;
end
$$;

comment on schema public is 'Shared application schema. RLS policy baselines are additive and do not grant anon/authenticated access.';
