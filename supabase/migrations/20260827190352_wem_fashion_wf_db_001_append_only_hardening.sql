drop policy if exists fashion_circular_events_service_role_all on fashion.circular_lifecycle_events;
revoke update, delete on fashion.circular_lifecycle_events from service_role;
grant select, insert on fashion.circular_lifecycle_events to service_role;
create policy fashion_circular_events_service_role_select on fashion.circular_lifecycle_events for select to service_role using (true);
create policy fashion_circular_events_service_role_insert on fashion.circular_lifecycle_events for insert to service_role with check (true);
comment on table fashion.circular_lifecycle_events is 'Append-only fashion lifecycle evidence. Service-role mutation is limited to SELECT/INSERT; correction is represented by subsequent evidence events. Events do not confer title, payment finality, certification, or regulatory approval.';
