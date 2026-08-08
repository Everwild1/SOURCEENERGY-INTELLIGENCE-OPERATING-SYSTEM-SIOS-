# SSR Reconciliation Record

## Current architecture-of-record interpretation

The SIOS SSR engineering layer distinguishes three grains that must not be conflated:

1. **AnchorTile / anchor column** — one of the 729 activated surface anchors.
2. **Spatial Cube** — one 3m volumetric unit at a Z index within an anchor column; the architecture describes 2,001 vertical positions per anchor.
3. **Dominion Grid governance assignment** — scroll, throne, protocol, institution, cluster, or cross-layer address. These assignments can be one-to-one, one-to-many, clustered, or abstract and are not the AnchorTile roster.

Under the current SSR architecture, 729 anchor columns × 2,001 vertical positions = 1,458,729 governed spatial assets.

## Addressing

Surface AnchorTiles use a source-supplied What3Words key such as `///three.words`. A volumetric Cube address extends that surface key with a Z index, e.g. `///three.words@Z+0000`.

Production identifiers and addresses must be generated or imported only from authoritative source records.

## Evidence status

Architecture documents and PRDs define the schema and deployment model. A small number of operational-context addresses are documented in narrative sources, but the authoritative 729-row AnchorTile master export has not been located in the connected Drive or this GitHub repository.

Therefore this repository establishes the engineering contract without manufacturing production data.

## Acceptance gate for canonical roster

Before a roster can be promoted to canonical status:

- row count must equal 729,
- `anchor_tile_id` must be unique and nonblank,
- `w3w_address` must be unique, source-supplied, and format-valid,
- latitude/longitude must be valid,
- activation date must be traceable,
- provenance must identify the system-of-record export,
- duplicate and synthetic rows must fail validation.
