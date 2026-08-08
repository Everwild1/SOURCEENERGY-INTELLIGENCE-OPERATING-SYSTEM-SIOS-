# SSR 729 AnchorTile Roster — Acquisition Runbook

Tracks GitHub Issue #2.

## Objective

Acquire a source-of-record export of the 729 activated SSR AnchorTiles without generating, inferring, or substituting identity data.

## Preferred acquisition order

1. PostgreSQL/PostGIS `anchor_tiles` table export.
2. Generated SSR registry packet.
3. Authenticated SSR API response.
4. Equivalent object-store export whose provenance can be tied to the registry backend.

## Database export

Run against the authoritative SSR database using a read-only account:

```sql
COPY (
  SELECT
    anchor_tile_id,
    w3w_address,
    latitude,
    longitude,
    activation_date,
    status,
    surface_crs,
    vertical_datum,
    source_system,
    source_record_id,
    source_exported_at
  FROM anchor_tiles
  ORDER BY anchor_tile_id
) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
```

Do not modify the production table during acquisition.

## Required operator handoff

Deliver:

- raw export, unchanged from source,
- export timestamp in UTC,
- source environment/system identifier,
- operator identity or service account reference,
- database/API/packet version where available,
- SHA-256 checksum of the raw export,
- row count reported at source,
- any filters used (expected: none for the canonical 729 activation roster).

## Local acceptance sequence

```bash
sha256sum anchor_tiles.raw.csv
python ssr/tools/validate_anchor_roster.py anchor_tiles.raw.csv
python ssr/tools/import_anchor_roster.py anchor_tiles.raw.csv ssr/data/anchor_tiles.canonical.csv
python ssr/tools/export_scorecard_sync.py ssr/data/anchor_tiles.canonical.csv /tmp/ssr-scorecard-sync.csv
```

Expected result: validator accepts exactly 729 rows and the scorecard sync artifact contains 729 data rows.

## Stop conditions

Stop and escalate if:

- source row count is not 729,
- IDs or W3W surface keys are duplicated,
- required fields are blank,
- coordinates are outside valid ranges,
- activation provenance cannot be established,
- export appears transformed before handoff,
- source is a narrative document rather than registry data,
- the operator proposes generated W3W values or inferred coordinates.

## Scorecard boundary

After technical validation, the generated synchronization artifact must receive human review before updating the Google Sheets `729-Cube Autonomy Scorecard`. Only SSR identity/address fields are synchronized. Autonomy Index, C0–C6, EDR, CCI, RM, interventions, and other analytical fields remain downstream.
