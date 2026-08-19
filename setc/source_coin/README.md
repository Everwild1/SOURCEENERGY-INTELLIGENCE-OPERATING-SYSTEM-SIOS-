# Source Coin

Source Coin is the governed economic interoperability layer for SETC. This module implements the Drive-controlled SC-01 through SC-12 specification baseline.

## Production gates

The following capabilities are disabled by default and must remain disabled until SC-E12 production authorization is satisfied:

- `SOURCE_COIN_MINT_ENABLED=false`
- `SOURCE_COIN_BURN_ENABLED=false`
- `SOURCE_COIN_PRODUCTION_ECONOMY_ENABLED=false`

## Backend boundary

Supabase is the backend platform target for persistence, authentication primitives, row-level security, controlled server-side orchestration, projections, and governed evidence storage. Supabase is not itself the economic authority. Source Coin domain rules and ledger invariants govern economic execution.

Direct client mutation of balances, ledger events, treasury state, mint/burn operations, or organization economic permissions is prohibited.

## Sprint 1 scope

- Foundation and governance traceability
- Ledger primitives and append-oriented event model
- Supabase migration baseline and RLS posture
- Organization wallet bindings
- Idempotency and replay resistance
- CI-oriented invariant checks

Tracked by GitHub issues #51, #52, and #54.
