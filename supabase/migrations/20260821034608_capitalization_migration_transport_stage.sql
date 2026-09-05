BEGIN;
CREATE SCHEMA IF NOT EXISTS migration_transport;
REVOKE ALL ON SCHEMA migration_transport FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA migration_transport TO service_role;
CREATE UNLOGGED TABLE IF NOT EXISTS migration_transport.statements (
    migration_name text NOT NULL,
    seq integer NOT NULL CHECK (seq > 0),
    statement_b64 text NOT NULL CHECK (length(statement_b64) > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (migration_name, seq)
);
ALTER TABLE migration_transport.statements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON migration_transport.statements FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON migration_transport.statements TO service_role;
COMMENT ON SCHEMA migration_transport IS 'Temporary, default-deny migration transport used to materialize validated Capitalization Block SQL; removed after deployment.';
COMMIT;
