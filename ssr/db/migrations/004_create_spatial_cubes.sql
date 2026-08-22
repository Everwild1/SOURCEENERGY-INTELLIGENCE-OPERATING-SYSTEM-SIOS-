-- SSR spatial cube identity contract.
-- Requires 001_create_anchor_tiles.sql. Does not seed production identities.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS spatial_cubes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cube_uid TEXT NOT NULL UNIQUE,
    anchor_tile_id TEXT NOT NULL REFERENCES anchor_tiles(anchor_tile_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    canonical_address TEXT NOT NULL UNIQUE,
    z_index INTEGER NOT NULL CHECK (z_index BETWEEN -1000 AND 1000),
    macro_layer TEXT,
    vertical_datum TEXT,
    canonical_representation TEXT NOT NULL UNIQUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT canonical_address_format CHECK (canonical_address ~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+@Z[+-][0-9]{4}$'),
    CONSTRAINT cube_uid_sha256_format CHECK (cube_uid ~ '^[0-9a-f]{64}$')
);

CREATE INDEX IF NOT EXISTS spatial_cubes_anchor_tile_idx ON spatial_cubes(anchor_tile_id);
CREATE INDEX IF NOT EXISTS spatial_cubes_z_idx ON spatial_cubes(z_index);

COMMENT ON TABLE spatial_cubes IS 'Deterministic SSR volumetric identities resolved only from a verified AnchorTile plus Z index.';

CREATE OR REPLACE FUNCTION ssr_resolve_cube(p_anchor_tile_id TEXT, p_z_index INTEGER)
RETURNS spatial_cubes
LANGUAGE plpgsql
AS $$
DECLARE
    v_anchor anchor_tiles%ROWTYPE;
    v_canonical_address TEXT;
    v_representation TEXT;
    v_uid TEXT;
    v_cube spatial_cubes%ROWTYPE;
BEGIN
    IF p_z_index < -1000 OR p_z_index > 1000 THEN
        RAISE EXCEPTION 'SSR Z index out of range: %', p_z_index;
    END IF;

    SELECT * INTO v_anchor FROM anchor_tiles WHERE anchor_tile_id = p_anchor_tile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown or unverified SSR AnchorTile: %', p_anchor_tile_id;
    END IF;

    v_canonical_address := v_anchor.w3w_address || '@Z' || CASE WHEN p_z_index >= 0 THEN '+' ELSE '-' END || lpad(abs(p_z_index)::text, 4, '0');
    v_representation := 'SSR|v1|' || v_anchor.anchor_tile_id || '|' || lower(v_anchor.w3w_address) || '|Z' || CASE WHEN p_z_index >= 0 THEN '+' ELSE '-' END || lpad(abs(p_z_index)::text, 4, '0') || '|CRS=' || v_anchor.surface_crs || '|VD=' || coalesce(v_anchor.vertical_datum, 'UNSPECIFIED');
    v_uid := encode(digest(convert_to(v_representation, 'UTF8'), 'sha256'), 'hex');

    INSERT INTO spatial_cubes(cube_uid, anchor_tile_id, canonical_address, z_index, vertical_datum, canonical_representation)
    VALUES(v_uid, v_anchor.anchor_tile_id, v_canonical_address, p_z_index, v_anchor.vertical_datum, v_representation)
    ON CONFLICT (cube_uid) DO UPDATE SET updated_at = NOW()
    RETURNING * INTO v_cube;

    RETURN v_cube;
END;
$$;
