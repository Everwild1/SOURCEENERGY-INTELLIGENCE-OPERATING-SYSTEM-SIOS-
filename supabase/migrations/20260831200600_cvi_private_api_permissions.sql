revoke all on table public.cvi_interface_config from anon, authenticated;
revoke all on table public.cvi_nodes from anon, authenticated;
revoke all on table public.cvi_watchtraces from anon, authenticated;
revoke all on table public.cvi_evidence_events from anon, authenticated;
revoke all on table public.cvi_live_status from anon, authenticated;

grant select, insert, update, delete on table public.cvi_interface_config to service_role;
grant select, insert, update, delete on table public.cvi_nodes to service_role;
grant select, insert, update, delete on table public.cvi_watchtraces to service_role;
grant select, insert, update, delete on table public.cvi_evidence_events to service_role;
grant select on table public.cvi_live_status to service_role;
