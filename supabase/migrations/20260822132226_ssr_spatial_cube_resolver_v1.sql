create extension if not exists pgcrypto;

create table if not exists public.spatial_cubes (
    id uuid primary key default gen_random_uuid(),
    cube_uid text not null unique,
    anchor_tile_id text not null references public.anchor_tiles(anchor_tile_id) on update cascade on delete restrict,
    canonical_address text not null unique,
    z_index integer not null check (z_index between -1000 and 1000),
    macro_layer text,
    vertical_datum text,
    canonical_representation text not null unique,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint canonical_address_format check (canonical_address ~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+@Z[+-][0-9]{4}$'),
    constraint cube_uid_sha256_format check (cube_uid ~ '^[0-9a-f]{64}$')
);

create index if not exists spatial_cubes_anchor_tile_idx on public.spatial_cubes(anchor_tile_id);
create index if not exists spatial_cubes_z_idx on public.spatial_cubes(z_index);

create or replace function public.ssr_resolve_cube(p_anchor_tile_id text, p_z_index integer)
returns public.spatial_cubes
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
    v_anchor public.anchor_tiles%rowtype;
    v_canonical_address text;
    v_representation text;
    v_uid text;
    v_cube public.spatial_cubes%rowtype;
begin
    if p_z_index < -1000 or p_z_index > 1000 then
        raise exception 'SSR Z index out of range: %', p_z_index;
    end if;

    select * into v_anchor from public.anchor_tiles where anchor_tile_id = p_anchor_tile_id;
    if not found then
        raise exception 'Unknown or unverified SSR AnchorTile: %', p_anchor_tile_id;
    end if;

    v_canonical_address := v_anchor.w3w_address || '@Z' || case when p_z_index >= 0 then '+' else '-' end || lpad(abs(p_z_index)::text, 4, '0');
    v_representation := 'SSR|v1|' || v_anchor.anchor_tile_id || '|' || lower(v_anchor.w3w_address) || '|Z' || case when p_z_index >= 0 then '+' else '-' end || lpad(abs(p_z_index)::text, 4, '0') || '|CRS=' || v_anchor.surface_crs || '|VD=' || coalesce(v_anchor.vertical_datum, 'UNSPECIFIED');
    v_uid := encode(digest(convert_to(v_representation, 'UTF8'), 'sha256'), 'hex');

    insert into public.spatial_cubes(cube_uid, anchor_tile_id, canonical_address, z_index, vertical_datum, canonical_representation)
    values(v_uid, v_anchor.anchor_tile_id, v_canonical_address, p_z_index, v_anchor.vertical_datum, v_representation)
    on conflict (cube_uid) do update set updated_at = now()
    returning * into v_cube;

    return v_cube;
end;
$$;

alter table public.spatial_cubes enable row level security;
revoke all on public.spatial_cubes from anon, authenticated;
revoke all on function public.ssr_resolve_cube(text, integer) from public, anon, authenticated;
