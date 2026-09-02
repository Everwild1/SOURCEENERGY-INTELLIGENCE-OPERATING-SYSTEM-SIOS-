create index if not exists energy_market_regions_market_id_idx on energy.market_regions(market_id);
create index if not exists energy_market_regions_parent_region_id_idx on energy.market_regions(parent_region_id);
create index if not exists energy_market_org_links_organization_oid_idx on energy.market_organization_links(organization_oid);
create index if not exists energy_market_org_links_market_id_idx on energy.market_organization_links(market_id);
create index if not exists energy_market_external_refs_market_id_idx on energy.market_external_references(market_id);
