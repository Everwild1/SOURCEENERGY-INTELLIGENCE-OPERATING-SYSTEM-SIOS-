do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename
    from pg_tables
    where schemaname in ('pqc','evidence')
  loop
    execute format('drop policy if exists service_role_all on %I.%I', r.schemaname, r.tablename);
    execute format('create policy service_role_all on %I.%I for all to service_role using (true) with check (true)', r.schemaname, r.tablename);
  end loop;
end $$;