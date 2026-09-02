BEGIN;
CREATE UNLOGGED TABLE IF NOT EXISTS migration_transport.payload_parts (
    part_no integer PRIMARY KEY CHECK (part_no >= 0),
    payload_b64 text NOT NULL CHECK (length(payload_b64) > 0),
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE migration_transport.payload_parts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON migration_transport.payload_parts FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON migration_transport.payload_parts TO service_role;
COMMIT;
