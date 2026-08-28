# ECO-E03 — Ecology Event Envelope & Event Catalog

Parent: #229  
Issue: #232  
Depends on: ECO-E01/#230, ECO-E02/#231

## Purpose
The Ecology event contract coordinates authoritative bounded domains without making the transport layer authoritative. It standardizes provenance, correlation, causation, idempotency, versioning and cross-domain references before ECO-E04 persistence.

## Envelope v1.0
Every Ecology event carries: event ID, stable event name, contract version, producer domain, source authority, correlation context, typed subject reference, optional related references, optional canonical SETC organization OID, timezone-aware occurred/recorded timestamps, and non-authoritative attributes.

Material events require an idempotency key. Correlation and causation semantics reuse the pattern already established by Source Coin RequestEnvelope/DomainEvent contracts.

## Event catalog
- `ecology.evidence.registered`
- `ecology.research.referenced`
- `ecology.ip.referenced`
- `ecology.commercialization.advanced`
- `ecology.market_opportunity.referenced`
- `ecology.capital_readiness.referenced`
- `ecology.transaction.referenced`
- `ecology.settlement.referenced`
- `ecology.impact.recorded`
- `ecology.regenerative_allocation.proposed`
- `ecology.reinvestment.referenced`

The catalog describes cross-domain handoffs in the ECO-E02 journey. Event names do not imply that Ecology owns the underlying object.

## Authority rules
1. Producer must equal the source domain of the subject reference.
2. Source authority must match the subject's source authority.
3. An Ecology envelope never transfers source authority, ownership, approval, verification, custody or settlement finality.
4. Source Coin settlement events remain references/economic-effect signals; Ecology does not infer fiat or regulated settlement finality.
5. WIM transaction references do not become Ecology transactions.
6. HEI IP/commercialization references do not transfer fiduciary or IP authority.
7. Capitalization references do not make Ecology a treasury, account or finality authority.
8. Evidence references are provenance pointers and do not manufacture verification.

## Replay and failure posture
Material cross-domain handoffs are fail-closed without an idempotency key. Consumers must persist receipt/replay state under ECO-E04 rather than relying on at-most-once transport. Duplicate delivery must not duplicate economic effects or governed decisions.

## Compatibility
ECO-E03 intentionally converges with the existing Source Coin correlation/causation/idempotency conventions and WIM integration-envelope pattern. Adapters translate domain-native messages into this Ecology projection contract; authoritative domain contracts remain unchanged.

## ECO-E04 handoff
The first `ecology` Supabase schema may persist event receipts, typed object references, journey edges, value-flow references, impact lineage and regenerative projections. It must not persist duplicate ledgers, balances, market transactions, organization masters, IP ownership masters, logistics execution or settlement-finality records.
