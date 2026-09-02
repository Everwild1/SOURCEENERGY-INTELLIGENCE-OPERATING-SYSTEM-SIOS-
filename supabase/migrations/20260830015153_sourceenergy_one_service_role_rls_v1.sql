create policy purpose_profiles_service_role_all on sourceenergy_one.purpose_profiles for all to service_role using (true) with check (true);
create policy codex24_interpretations_service_role_all on sourceenergy_one.codex24_interpretations for all to service_role using (true) with check (true);
create policy impact_reports_service_role_all on sourceenergy_one.impact_reports for all to service_role using (true) with check (true);
create policy genesis_approvals_service_role_all on sourceenergy_one.genesis_approvals for all to service_role using (true) with check (true);
create policy genesis_packages_service_role_all on sourceenergy_one.genesis_packages for all to service_role using (true) with check (true);
create policy orchestration_plans_service_role_all on sourceenergy_one.orchestration_plans for all to service_role using (true) with check (true);
create policy audit_events_service_role_all on sourceenergy_one.audit_events for all to service_role using (true) with check (true);

alter default privileges in schema sourceenergy_one revoke all on tables from public, anon, authenticated;
alter default privileges in schema sourceenergy_one grant all on tables to service_role;
alter default privileges in schema sourceenergy_one grant usage, select on sequences to service_role;
