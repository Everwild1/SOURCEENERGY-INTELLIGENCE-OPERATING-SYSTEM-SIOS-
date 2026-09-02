create or replace function rw_private.current_registry_access()
returns table(role text, organization_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select m.role::text, m.organization_id
  from rw_private.registry_access_memberships m
  where m.auth_user_id = (select auth.uid())
    and m.is_active
    and m.effective_at <= now()
    and (m.expires_at is null or m.expires_at > now())
  order by m.role::text, m.organization_id nulls first;
$$;

revoke all on function rw_private.current_registry_access() from public, anon;
grant execute on function rw_private.current_registry_access() to authenticated, service_role;

create or replace function rw.current_registry_access()
returns table(role text, organization_id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
  select a.role, a.organization_id
  from rw_private.current_registry_access() a;
$$;

revoke all on function rw.current_registry_access() from public, anon;
grant execute on function rw.current_registry_access() to authenticated, service_role;
