# SC-E10 — SETC / Source Block Integration

## Authority chain

SETC Core / Organizations -> Source Blocks -> Source Coin integration ingress -> policy/authorization -> ledger execution -> events/projections.

Source Blocks originate governed evidence and economic requests. They do **not** write balances, ledger events, treasury state, reward execution state, or supply state.

## Organization identity

Institutional requests use canonical `SETC-OID-*` identifiers. Organization status and authorization remain prerequisites to economic execution.

## Event boundary

Every request carries correlation, causation, provenance and idempotency identifiers so SC-E08 domain events can preserve end-to-end traceability. Redelivery of an integration request must not imply duplicate economic execution.

## Projection boundary

Supabase projections, Realtime consumers, indexers, analytics and accounting exports are downstream read models. They may be rebuilt from authoritative events and cannot independently create economic effects.

## Chain anchoring

A chain anchor is evidence/proof metadata. Its presence does not authorize settlement, rewards, treasury movement, minting, burning or any other economic operation. Deployments using a Foundation/side-chain anchor must separately define finality, reorganization handling, proof verification, confidentiality and recovery behavior.

## Institutional gateway

External universities, research institutions, enterprises and public bodies enter through authenticated organization-linked gateways. No external integration receives direct database mutation authority over Source Coin economic tables.

## Accounting and reserve boundary

Protocol transaction classes are not accounting classifications. Source Coin circulating supply, treasury balances, reserve assets and fiat/other external assets remain explicitly distinct and are reconciled through controlled reporting interfaces.

## Failure isolation

Projection/indexer outages must not corrupt the ledger. Mandatory identity, authorization or compliance dependencies fail closed. Retries use idempotency keys and correlation identifiers.

## Production gate

SC-E10 integration does not authorize production economics. Mint, burn and production economy remain disabled until SC-E12 is independently satisfied.
