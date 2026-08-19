# SSR Supabase Production Ingestion Runbook

Parent dependency: GitHub Issue #2. Readiness workstream: Issue #67.

## Authority boundary

`public.anchor_tiles` in Supabase project `SourceEnergy-command-backend` is the authoritative SSR production table. The schema is deployed but currently contains zero production rows.

No IDs, What3Words addresses, coordinates, activation timestamps, or provenance values may be generated to satisfy the 729-row requirement.

## Required handoff

Acquire one unchanged authoritative 729-row source artifact containing at minimum:

- `anchor_tile_id`
- `w3w_address`
- `latitude`
- `longitude`
- `activation_date`
- `source_system`

Preserve source environment, UTC export timestamp, source row count, SHA-256 checksum, and source/version reference.

## Pre-ingestion gate

1. Preserve the raw source artifact unchanged.
2. Verify its SHA-256 checksum and provenance metadata.
3. Run the repository roster validator against the raw export.
4. Confirm exactly 729 records and zero identity/address duplicates.
5. Confirm coordinate ranges and activation/provenance completeness.
6. Confirm `public.anchor_tiles` is empty before the first production load unless a separately approved replacement procedure exists.

Stop on any failed gate.

## Production load

Use a controlled database-side or authenticated administrative import. Do not expose database passwords, service-role keys, or connection strings in source control.

The import must preserve source values exactly for canonical identity, What3Words address, coordinates, activation date, and provenance. Database-generated `created_at` and `geom` values may be produced by the deployed schema.

Do not use an upsert to conceal collisions. A duplicate primary key or unique What3Words address is a fail-closed condition requiring source review.

## Post-ingestion verification

Run `ssr/tools/supabase_anchor_tiles_preflight.sql` and require:

- row count = 729
- blank AnchorTile IDs = 0
- duplicate AnchorTile IDs = 0
- blank W3W addresses = 0
- duplicate W3W addresses = 0
- invalid coordinates = 0
- missing activation dates = 0
- missing source-system provenance = 0

Then run the repository normalization and scorecard synchronization pipeline defined by Issue #2.

## Rollback / failure handling

If ingestion fails before commit, roll back the transaction. If a committed load is later shown to be invalid, preserve the raw source and audit evidence, stop downstream synchronization, and use a separately reviewed corrective transaction rather than silently overwriting production records.

## RLS hardening boundary

RLS is currently disabled on `public.anchor_tiles`. Do not enable it as an incidental part of ingestion. First approve the intended access model: backend-only, authenticated read, or another explicit policy. Then enable RLS and add least-privilege policies in a separately reviewed change. Never expose service-role credentials to clients.

## Completion

Issue #67 closes when readiness controls are merged. Issue #2 closes only after the authentic 729-row production roster is loaded into Supabase, passes all validation gates, is normalized, and the downstream scorecard identity/address synchronization is reviewed and completed.
