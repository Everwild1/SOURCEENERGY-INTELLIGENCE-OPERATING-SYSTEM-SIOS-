create policy system_heartbeat_service_role_all
on public.system_heartbeat_registry
for all
to service_role
using (true)
with check (true);
