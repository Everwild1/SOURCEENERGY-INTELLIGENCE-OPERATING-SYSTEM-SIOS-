do $$
declare
  r record;
begin
  for r in
    select c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'rw'
      and c.relkind = 'r'
      and c.relrowsecurity
      and not exists (
        select 1
        from pg_policies p
        where p.schemaname = 'rw'
          and p.tablename = c.relname
      )
      and not exists (
        select 1
        from information_schema.role_table_grants g
        where g.table_schema = 'rw'
          and g.table_name = c.relname
          and g.grantee in ('anon','authenticated')
      )
  loop
    execute format(
      'create policy %I on rw.%I for all to anon, authenticated using (false) with check (false)',
      'rw_explicit_service_only_deny',
      r.table_name
    );
  end loop;
end
$$;
