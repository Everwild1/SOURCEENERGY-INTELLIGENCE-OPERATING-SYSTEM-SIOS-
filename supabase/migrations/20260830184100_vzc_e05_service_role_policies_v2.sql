-- VZC-E05 RLS service boundary
create policy vzc_mobility_safety_bindings_service_role_all on vzc.mobility_safety_bindings for all to service_role using (true) with check (true);
create policy vzc_multimodal_safety_events_service_role_all on vzc.multimodal_safety_events for all to service_role using (true) with check (true);
create policy vzc_mobility_authority_boundaries_service_role_all on vzc.mobility_authority_boundaries for all to service_role using (true) with check (true);
create policy vzc_drone_safety_authority_checks_service_role_all on vzc.drone_safety_authority_checks for all to service_role using (true) with check (true);
