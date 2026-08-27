-- Recovered from production supabase_migrations.schema_migrations.
-- SSR architecture contract. This migration defines structure only; it does not seed production records.
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS anchor_tiles (
    anchor_tile_id TEXT PRIMARY KEY,
    w3w_address TEXT NOT NULL UNIQUE,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    activation_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    geom geometry(Point, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)) STORED,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS anchor_tiles_geom_gix ON anchor_tiles USING GIST (geom);
CREATE INDEX IF NOT EXISTS anchor_tiles_activation_date_idx ON anchor_tiles (activation_date);
