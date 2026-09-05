create or replace function public.ssr_ingest_anchor_stage_insert(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, ssr_ingest, pg_temp
as $$
declare
  v_batch_id uuid;
  v_anchor_tile_id text;
  v_w3w_address text;
  v_latitude double precision;
  v_longitude double precision;
  v_ssr_level integer;
begin
  if current_user <> 'service_role' and session_user <> 'service_role' then
    raise exception 'service_role required' using errcode = '42501';
  end if;

  insert into ssr_ingest.anchor_tiles_stage (
    batch_id, anchor_tile_id, activation_date, source_system,
    latitude, longitude, w3w_address, ssr_level
  ) values (
    (p_row->>'batch_id')::uuid,
    p_row->>'anchor_tile_id',
    (p_row->>'activation_date')::timestamptz,
    p_row->>'source_system',
    (p_row->>'latitude')::double precision,
    (p_row->>'longitude')::double precision,
    p_row->>'w3w_address',
    coalesce((p_row->>'ssr_level')::integer, 2001)
  )
  returning batch_id, anchor_tile_id, w3w_address, latitude, longitude, ssr_level
  into v_batch_id, v_anchor_tile_id, v_w3w_address, v_latitude, v_longitude, v_ssr_level;

  return jsonb_build_object(
    'batch_id', v_batch_id,
    'anchor_tile_id', v_anchor_tile_id,
    'ssr_level', v_ssr_level,
    'w3w_address', v_w3w_address,
    'latitude', v_latitude,
    'longitude', v_longitude
  );
end;
$$;
revoke all on function public.ssr_ingest_anchor_stage_insert(jsonb) from public, anon, authenticated;
grant execute on function public.ssr_ingest_anchor_stage_insert(jsonb) to service_role;
notify pgrst, 'reload schema';
