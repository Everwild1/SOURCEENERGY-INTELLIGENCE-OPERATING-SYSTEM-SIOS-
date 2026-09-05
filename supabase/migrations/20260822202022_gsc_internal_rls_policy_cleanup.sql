drop policy if exists gsc_commodities_service_role_all on gsc.commodities;
drop policy if exists gsc_supply_nodes_service_role_all on gsc.supply_nodes;
drop policy if exists gsc_corridor_portfolio_service_role_all on gsc.corridor_portfolio;
drop policy if exists gsc_distribution_programs_service_role_all on gsc.distribution_programs;
drop policy if exists gsc_distribution_program_commodities_service_role_all on gsc.distribution_program_commodities;

comment on schema gsc is 'Internal Global Supply Chain orchestration schema. Not intended for direct browser/client Data API exposure. Access through governed backend/API projections.';
