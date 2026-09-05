grant usage on schema ssr_ingest to service_role;
grant select, insert, update, delete on table ssr_ingest.anchor_tiles_stage to service_role;
grant select, insert, update, delete on table ssr_ingest.batches to service_role;
grant usage, select on all sequences in schema ssr_ingest to service_role;
