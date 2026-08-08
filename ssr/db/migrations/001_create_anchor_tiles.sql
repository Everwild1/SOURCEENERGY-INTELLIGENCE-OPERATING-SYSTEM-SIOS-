-- SSR architecture contract. This migration defines structure only; it does not seed production records.
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS anchor_tiles (
    anchor_tile_id TEXT PRIMARY KEY,
    w3w_address TEXT NOT NULL UNIQUE,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    activation_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    surface_crs TEXT NOT NULL DEFAULT 'EPSG:4326',
    vertical_datum TEXT,
    source_system TEXT NOT NULL,
    source_record_id TEXT,
    source_exported_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    geom geometry(Point, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)) STORED,
    CONSTRAINT w3w_surface_format CHECK (w3w_address ~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$')
);

CREATE INDEX IF NOT EXISTS anchor_tiles_geom_gix ON anchor_tiles USING GIST (geom);
CREATE INDEX IF NOT EXISTS anchor_tiles_activation_date_idx ON anchor_tiles (activation_date);

COMMENT ON TABLE anchor_tiles IS 'Authoritative SSR surface AnchorTiles. Production rows must originate from a traceable registry export/API/database source.';
