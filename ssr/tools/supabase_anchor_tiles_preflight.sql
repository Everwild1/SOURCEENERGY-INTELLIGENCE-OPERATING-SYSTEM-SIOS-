-- SSR Supabase production preflight: read-only validation gates.
-- Run before and after authoritative ingestion. This file performs no writes.

select count(*) as row_count from public.anchor_tiles;

select
  count(*) filter (where anchor_tile_id is null or btrim(anchor_tile_id) = '') as blank_anchor_tile_ids,
  count(*) - count(distinct anchor_tile_id) as duplicate_anchor_tile_ids,
  count(*) filter (where w3w_address is null or btrim(w3w_address) = '') as blank_w3w_addresses,
  count(*) - count(distinct w3w_address) as duplicate_w3w_addresses,
  count(*) filter (where latitude < -90 or latitude > 90) as invalid_latitudes,
  count(*) filter (where longitude < -180 or longitude > 180) as invalid_longitudes,
  count(*) filter (where activation_date is null) as missing_activation_dates,
  count(*) filter (where source_system is null or btrim(source_system) = '') as missing_source_systems
from public.anchor_tiles;

select source_system, count(*) as row_count
from public.anchor_tiles
group by source_system
order by source_system;

select status, count(*) as row_count
from public.anchor_tiles
group by status
order by status;

-- PASS contract after ingestion:
-- row_count = 729
-- all blank/duplicate/invalid/missing counters = 0
-- source_system values must match the approved handoff provenance
