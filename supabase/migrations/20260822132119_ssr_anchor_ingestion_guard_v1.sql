create schema if not exists ssr_ingest;
revoke all on schema ssr_ingest from public, anon, authenticated;

create table if not exists ssr_ingest.batches (
 id uuid primary key default gen_random_uuid(),
 source_system text not null,
 source_environment text,
 source_exported_at timestamptz not null,
 source_row_count integer not null check(source_row_count > 0),
 source_sha256 text not null check(source_sha256 ~ '^[0-9a-fA-F]{64}$'),
 source_reference text,
 operator_reference text,
 status text not null default 'received' check(status in ('received','validated','rejected','loaded')),
 validation_summary jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 validated_at timestamptz,
 loaded_at timestamptz
);

create table if not exists ssr_ingest.anchor_tiles_stage (
 batch_id uuid not null references ssr_ingest.batches(id) on delete cascade,
 anchor_tile_id text not null,
 w3w_address text not null,
 latitude double precision not null,
 longitude double precision not null,
 activation_date timestamptz not null,
 status text not null default 'active',
 surface_crs text not null default 'EPSG:4326',
 vertical_datum text,
 source_system text not null,
 source_record_id text,
 source_exported_at timestamptz,
 primary key(batch_id, anchor_tile_id)
);
create unique index if not exists ssr_stage_batch_w3w_uq on ssr_ingest.anchor_tiles_stage(batch_id, lower(w3w_address));

create or replace function ssr_ingest.validate_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, ssr_ingest
as $$
declare
  v_expected integer;
  v_total integer;
  v_unique_ids integer;
  v_unique_w3w integer;
  v_bad_coords integer;
  v_bad_w3w integer;
  v_missing_source integer;
  v_result jsonb;
begin
  select source_row_count into v_expected from ssr_ingest.batches where id=p_batch_id;
  if v_expected is null then raise exception 'Unknown ingestion batch %', p_batch_id; end if;

  select count(*), count(distinct anchor_tile_id), count(distinct lower(w3w_address)),
         count(*) filter(where latitude not between -90 and 90 or longitude not between -180 and 180),
         count(*) filter(where w3w_address !~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$'),
         count(*) filter(where nullif(trim(source_system),'') is null)
  into v_total,v_unique_ids,v_unique_w3w,v_bad_coords,v_bad_w3w,v_missing_source
  from ssr_ingest.anchor_tiles_stage where batch_id=p_batch_id;

  v_result := jsonb_build_object(
    'expected_rows',v_expected,'staged_rows',v_total,'unique_ids',v_unique_ids,'unique_w3w',v_unique_w3w,
    'bad_coordinates',v_bad_coords,'bad_w3w',v_bad_w3w,'missing_source_system',v_missing_source,
    'passes', (v_expected=729 and v_total=729 and v_unique_ids=729 and v_unique_w3w=729 and v_bad_coords=0 and v_bad_w3w=0 and v_missing_source=0)
  );

  update ssr_ingest.batches
  set status=case when (v_result->>'passes')::boolean then 'validated' else 'rejected' end,
      validation_summary=v_result, validated_at=now()
  where id=p_batch_id;
  return v_result;
end;
$$;

create or replace function ssr_ingest.load_validated_batch(p_batch_id uuid)
returns integer
language plpgsql
security invoker
set search_path = pg_catalog, public, ssr_ingest
as $$
declare v_status text; v_count integer;
begin
  select status into v_status from ssr_ingest.batches where id=p_batch_id for update;
  if v_status is distinct from 'validated' then raise exception 'Batch % is not validated', p_batch_id; end if;

  if exists(select 1 from public.anchor_tiles) then
    raise exception 'public.anchor_tiles is not empty; refusing uncontrolled replacement';
  end if;

  insert into public.anchor_tiles(anchor_tile_id,w3w_address,latitude,longitude,activation_date,status,surface_crs,vertical_datum,source_system,source_record_id,source_exported_at)
  select anchor_tile_id,w3w_address,latitude,longitude,activation_date,status,surface_crs,vertical_datum,source_system,source_record_id,source_exported_at
  from ssr_ingest.anchor_tiles_stage where batch_id=p_batch_id order by anchor_tile_id;

  get diagnostics v_count = row_count;
  if v_count <> 729 then raise exception 'Loaded %, expected 729', v_count; end if;
  update ssr_ingest.batches set status='loaded', loaded_at=now() where id=p_batch_id;
  return v_count;
end;
$$;

revoke all on all tables in schema ssr_ingest from public, anon, authenticated;
revoke all on all functions in schema ssr_ingest from public, anon, authenticated;
alter table public.anchor_tiles enable row level security;
revoke all on public.anchor_tiles from anon, authenticated;
