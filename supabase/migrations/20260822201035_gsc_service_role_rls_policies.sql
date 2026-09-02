create policy gsc_commodities_service_role_all on gsc.commodities for all to service_role using (true) with check (true);
create policy gsc_supply_nodes_service_role_all on gsc.supply_nodes for all to service_role using (true) with check (true);
create policy gsc_corridor_portfolio_service_role_all on gsc.corridor_portfolio for all to service_role using (true) with check (true);
create policy gsc_distribution_programs_service_role_all on gsc.distribution_programs for all to service_role using (true) with check (true);
create policy gsc_distribution_program_commodities_service_role_all on gsc.distribution_program_commodities for all to service_role using (true) with check (true);
