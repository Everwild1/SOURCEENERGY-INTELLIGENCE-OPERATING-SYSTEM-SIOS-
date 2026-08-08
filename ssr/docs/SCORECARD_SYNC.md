# SSR → 729-Cube Autonomy Scorecard Synchronization

## Governance rule

The Google Sheets scorecard is a downstream analytical surface. It is not the system of record for AnchorTile identity.

The synchronization source must be a roster that has passed `validate_anchor_roster.py` with exactly 729 authoritative rows.

## Deterministic mapping

`export_scorecard_sync.py` sorts validated records by authoritative `anchor_tile_id` (case-insensitive), with W3W as a deterministic tie-breaker. It then assigns spreadsheet rows 2 through 730.

This ordering is an integration convention, not a replacement for the source-system identity. If the operational SSR later supplies an explicit immutable sequence/order field, that field should supersede this convention through a reviewed schema change.

## Scorecard fields

The sync export supplies:

- `scorecard_row`
- `anchor_tile_id`
- `canonical_anchor_address` derived deterministically as `W3W_Address@Z+0000`
- source W3W surface key
- latitude / longitude
- activation date
- status
- source system / source record ID

The autonomy metrics, domain scores, C0-C6 classification, EDR, CCI, RM, and intervention fields remain analytical data owned by the scorecard/workflow and must not overwrite SSR master identity.

## Google Sheets write boundary

When the production roster becomes available:

1. validate the source export,
2. normalize it into the canonical repository artifact,
3. generate the scorecard sync CSV,
4. compare 729 existing scorecard rows against the sync artifact,
5. update identity/address columns only after review,
6. preserve analytical scoring columns and formulas,
7. record the source export timestamp/commit used for the synchronization.

No script in this repository directly writes to Google Sheets yet. That connector boundary should use service credentials or an approved integration runtime and should consume only the validated sync artifact.
