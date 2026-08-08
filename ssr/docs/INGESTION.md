# AnchorTile Roster Ingestion Pipeline

## Objective

Convert a traceable SSR system-of-record export into a normalized 729-row ingestion artifact without generating or inferring production identity data.

## Supported source formats

- CSV with a header row
- JSON array of row objects
- JSON object containing a `records` array

## Required fields

- `anchor_tile_id`
- `w3w_address` — surface key only (`///word.word.word`), not a Z-indexed Cube address
- `latitude`
- `longitude`
- `activation_date`
- `source_system`

## Validation gate

Run:

```bash
python ssr/tools/validate_anchor_roster.py path/to/export.csv
```

Production validation requires exactly 729 rows and rejects:

- missing required values,
- duplicate AnchorTile IDs,
- duplicate W3W surface keys,
- malformed or Z-indexed W3W values,
- invalid latitude/longitude,
- unparseable activation timestamps.

The validator does not call What3Words or any geocoding service. It verifies structural integrity and provenance fields only.

## Canonical normalization

After validation:

```bash
python ssr/tools/import_anchor_roster.py path/to/export.csv ssr/data/anchor_tiles.canonical.csv
```

The importer refuses to overwrite an existing canonical artifact. Replacement therefore requires an explicit governance action rather than an accidental rerun.

## Tests

```bash
python -m unittest ssr/tests/test_validate_anchor_roster.py
```

Tests use synthetic fixtures solely to exercise validation logic. They are not production AnchorTile records and are never written to `ssr/data/`.

## Downstream reconciliation

Only after the canonical 729-row artifact passes validation should its stable AnchorTile identities be mapped into the 729-Cube Autonomy Scorecard and expanded into Z-indexed Cube records where required.
