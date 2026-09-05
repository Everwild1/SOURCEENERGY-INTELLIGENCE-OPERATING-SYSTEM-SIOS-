-- SSR staged-to-production promotion control.
-- Encodes the gates in ssr/docs/SUPABASE_PRODUCTION_INGESTION_RUNBOOK.md as
-- fail-closed database logic. Defines control logic only; seeds no production
-- records and promotes nothing on its own.

create or replace function ssr_ingest.preflight_batch(
  p_batch_id uuid,
  p_expected_rows integer default 729
)
returns jsonb
language sql
stable
security invoker
set search_path = ssr_ingest, public, pg_temp
as $fn$
  with batch as (
    select * from ssr_ingest.anchor_tiles_stage where batch_id = p_batch_id
  ),
  counters as (
    select
      count(*) as row_count,
      count(*) filter (where anchor_tile_id is null or btrim(anchor_tile_id) = '') as blank_anchor_tile_ids,
      count(*) - count(distinct anchor_tile_id) as duplicate_anchor_tile_ids,
      count(*) filter (where w3w_address is null or btrim(w3w_address) = '') as blank_w3w_addresses,
      count(*) - count(distinct w3w_address) as duplicate_w3w_addresses,
      count(*) filter (where latitude is null or latitude < -90 or latitude > 90) as invalid_latitudes,
      count(*) filter (where longitude is null or longitude < -180 or longitude > 180) as invalid_longitudes,
      count(*) filter (where activation_date is null) as missing_activation_dates,
      count(*) filter (where source_system is null or btrim(source_system) = '') as missing_source_systems,
      count(*) filter (where w3w_address !~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$') as malformed_w3w_addresses
    from batch
  ),
  collisions as (
    select
      count(*) filter (where exists (select 1 from public.anchor_tiles p where p.anchor_tile_id = b.anchor_tile_id)) as anchor_tile_id_collisions,
      count(*) filter (where exists (select 1 from public.anchor_tiles p where p.w3w_address = b.w3w_address)) as w3w_address_collisions
    from batch b
  )
  select jsonb_build_object(
    'batch_id', p_batch_id,
    'expected_rows', p_expected_rows,
    'production_row_count', (select count(*) from public.anchor_tiles),
    'row_count', c.row_count,
    'row_count_matches', c.row_count = p_expected_rows,
    'blank_anchor_tile_ids', c.blank_anchor_tile_ids,
    'duplicate_anchor_tile_ids', c.duplicate_anchor_tile_ids,
    'blank_w3w_addresses', c.blank_w3w_addresses,
    'duplicate_w3w_addresses', c.duplicate_w3w_addresses,
    'malformed_w3w_addresses', c.malformed_w3w_addresses,
    'invalid_latitudes', c.invalid_latitudes,
    'invalid_longitudes', c.invalid_longitudes,
    'missing_activation_dates', c.missing_activation_dates,
    'missing_source_systems', c.missing_source_systems,
    'anchor_tile_id_collisions', x.anchor_tile_id_collisions,
    'w3w_address_collisions', x.w3w_address_collisions,
    'source_systems', (select jsonb_object_agg(source_system, n) from (select source_system, count(*) as n from batch group by source_system) s),
    'would_pass', c.row_count = p_expected_rows
                  and c.blank_anchor_tile_ids = 0
                  and c.duplicate_anchor_tile_ids = 0
                  and c.blank_w3w_addresses = 0
                  and c.duplicate_w3w_addresses = 0
                  and c.malformed_w3w_addresses = 0
                  and c.invalid_latitudes = 0
                  and c.invalid_longitudes = 0
                  and c.missing_activation_dates = 0
                  and c.missing_source_systems = 0
                  and x.anchor_tile_id_collisions = 0
                  and x.w3w_address_collisions = 0
  )
  from counters c, collisions x;
$fn$;

comment on function ssr_ingest.preflight_batch(uuid, integer) is
  'Read-only promotion gate report for one staged batch. Performs no writes. would_pass=true is necessary but not sufficient: promote_batch re-checks every gate inside the write transaction.';

create or replace function ssr_ingest.promote_batch(
  p_batch_id uuid,
  p_expected_rows integer default 729,
  p_allow_nonempty_production boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ssr_ingest, public, pg_temp
as $fn$
declare
  v_report jsonb;
  v_prod_before bigint;
  v_inserted bigint;
begin
  select count(*) into v_prod_before from public.anchor_tiles;
  if v_prod_before > 0 and not p_allow_nonempty_production then
    raise exception 'SSR promotion BLOCKED: public.anchor_tiles already holds % row(s). A replacement load requires separate approval (p_allow_nonempty_production).', v_prod_before;
  end if;

  v_report := ssr_ingest.preflight_batch(p_batch_id, p_expected_rows);

  if (v_report->>'row_count')::bigint = 0 then
    raise exception 'SSR promotion BLOCKED: batch % holds no staged rows.', p_batch_id;
  end if;

  if not (v_report->>'would_pass')::boolean then
    raise exception 'SSR promotion BLOCKED: preflight gates failed. Report: %', v_report;
  end if;

  insert into public.anchor_tiles (
    anchor_tile_id, w3w_address, latitude, longitude, activation_date,
    status, surface_crs, vertical_datum,
    source_system, source_record_id, source_exported_at,
    authority_signature, metadata_hash
  )
  select
    s.anchor_tile_id, s.w3w_address, s.latitude, s.longitude, s.activation_date,
    coalesce(s.status, 'active'), coalesce(s.surface_crs, 'EPSG:4326'), s.vertical_datum,
    s.source_system, s.source_record_id, s.source_exported_at,
    s.authority_signature, s.metadata_hash
  from ssr_ingest.anchor_tiles_stage s
  where s.batch_id = p_batch_id;

  get diagnostics v_inserted = row_count;

  if v_inserted <> p_expected_rows then
    raise exception 'SSR promotion BLOCKED: inserted % row(s), expected %. Transaction rolled back.', v_inserted, p_expected_rows;
  end if;

  return jsonb_build_object(
    'promoted', true,
    'batch_id', p_batch_id,
    'rows_promoted', v_inserted,
    'production_row_count', (select count(*) from public.anchor_tiles),
    'preflight', v_report,
    'promoted_at', now()
  );
end;
$fn$;

comment on function ssr_ingest.promote_batch(uuid, integer, boolean) is
  'Fail-closed promotion of one staged batch into public.anchor_tiles. Re-checks every runbook gate inside the write transaction; any failure rolls back the entire load. Never upserts.';

revoke all on function ssr_ingest.preflight_batch(uuid, integer) from public;
revoke all on function ssr_ingest.promote_batch(uuid, integer, boolean) from public;
grant execute on function ssr_ingest.preflight_batch(uuid, integer) to service_role;
grant execute on function ssr_ingest.promote_batch(uuid, integer, boolean) to service_role;
