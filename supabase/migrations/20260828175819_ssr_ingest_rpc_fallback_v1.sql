create or replace function public.ssr_ingest_anchor_stage_insert(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, ssr_ingest, pg_temp
as $$
declare
  v ssr_ingest.anchor_tiles_stage%rowtype;
begin
  if current_user <> 'service_role' and session_user <> 'service_role' then
    raise exception 'service_role required' using errcode = '42501';
  end if;

  insert into ssr_ingest.anchor_tiles_stage (
    batch_id, anchor_tile_id, activation_date, source_system,
    latitude, longitude, w3w_address, ssr_level
  ) values (
    p_row->>'batch_id',
    p_row->>'anchor_tile_id',
    (p_row->>'activation_date')::date,
    p_row->>'source_system',
    (p_row->>'latitude')::double precision,
    (p_row->>'longitude')::double precision,
    p_row->>'w3w_address',
    coalesce((p_row->>'ssr_level')::integer, 2001)
  ) returning * into v;

  return jsonb_build_object(
    'id', v.id,
    'ssr_level', v.ssr_level,
    'w3w_address', v.w3w_address,
    'latitude', v.latitude,
    'longitude', v.longitude
  );
end;
$$;
revoke all on function public.ssr_ingest_anchor_stage_insert(jsonb) from public, anon, authenticated;
grant execute on function public.ssr_ingest_anchor_stage_insert(jsonb) to service_role;
notify pgrst, 'reload schema';
