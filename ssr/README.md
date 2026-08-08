# SourceEnergy Spatial Registry (SSR)

This directory establishes the governed engineering boundary for Scroll #411 / SourceEnergy Spatial Registry inside SIOS.

## Purpose

The repository currently does **not** contain the authoritative production AnchorTile roster. This scaffold defines how that data must be represented, validated, imported, and exported once retrieved from the system of record.

## Architecture boundary

- 729 = activated AnchorTiles / anchor columns.
- Each AnchorTile may address a vertical lattice of 2,001 3m cubes from Z-1000 through Z+1000.
- The 392-scroll Dominion Grid registry is a governance-assignment registry and is not a one-to-one substitute for the 729 AnchorTile roster.
- Narrative documents, examples, and illustrative What3Words addresses must never be promoted into canonical production rows without source-of-record evidence.

## Directory map

- `db/migrations/` — canonical relational schema.
- `schemas/` — machine-readable import/export contracts.
- `data/` — controlled roster ingestion area. Production data is intentionally absent until sourced.
- `docs/` — reconciliation and governance notes.

## Production ingestion gate

A 729-row AnchorTile roster may be accepted only when every row contains:

1. stable `anchor_tile_id`,
2. source-supplied `w3w_address`,
3. valid WGS84 latitude and longitude,
4. traceable activation date/timestamp,
5. no duplicate AnchorTile IDs,
6. no duplicate W3W surface keys,
7. provenance identifying the registry export/API/database source.

Synthetic, inferred, or narrative-example addresses are rejected.
