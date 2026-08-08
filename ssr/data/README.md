# SSR Data Ingestion Area

No production AnchorTile roster is committed here yet.

## Required source

The accepted source must be one of:

- direct `anchor_tiles` database export,
- generated SSR registry packet,
- authenticated SSR API response,
- other system-of-record export with equivalent provenance.

## Required completeness

The canonical activation roster is expected to contain 729 unique AnchorTile records. An import is rejected if it contains blanks, duplicate IDs, duplicate W3W surface keys, invalid coordinates, or rows whose provenance cannot be traced.

## Prohibited

Do not seed this directory with:

- `Cube-001` through `Cube-729` placeholders presented as canonical IDs,
- generated What3Words strings,
- addresses copied from narrative examples without roster identity,
- coordinates inferred from place names,
- Dominion Grid scroll addresses treated as AnchorTile records.

Verified narrative examples may remain in evidence registers outside the production roster, but they do not satisfy the ingestion gate.
