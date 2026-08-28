# ECO-E07 — API / Integration Gateway

## Purpose
ECO-E07 defines the contract boundary through which Ecology transports cross-domain requests and receives acknowledgements/results. The gateway is a coordination layer, not a new authority plane.

## Contract v1.0
Every material request carries a request ID, target domain, allowlisted action, ECO-E03 correlation/causation/idempotency context, typed ECO-E01 subject/reference objects, optional SETC organization identity, timestamp and explainability attributes.

Material requests require idempotency and fail closed when the action is not allowlisted for the target domain.

## Adapter boundaries
- WIM: market-workflow request only.
- Capitalization: capital review / regenerative proposal submission only.
- Source Coin: settlement/economic-effect request only; never ledger mutation and never release-gate bypass.
- HEI: institutional review / regenerative proposal submission only.
- GSC/RGL: logistics review request only.
- SETC/Source Block: provenance review request only.
- External authority: reference registration only in v1.0; Ecology does not command external legal/financial authorities.

## Receipt semantics
A gateway receipt may mean `received`, `rejected`, or `accepted_for_review`. None of these states proves execution, settlement finality, approval, ownership, ledger mutation, or business completion. Where an authoritative domain later produces a result, Ecology stores only a typed reference to that result.

## Source Coin safeguard
Source Coin remains authoritative for its own economic effects. `REQUEST_SETTLEMENT` is a request-only message and cannot bypass any Source Coin governance/release gate. ECO-E07 therefore cannot turn an Ecology allocation proposal into a Source Coin transaction.

## ECO-E08 handoff
The synthetic pilot will instantiate mock authoritative adapters and exercise the full loop: evidence/research → commercialization → market → capital → transaction → settlement reference → impact → regenerative proposal → reinvestment reference. The pilot must prove correlation, replay protection, authority preservation and non-finality of gateway acknowledgements before any production networking is considered.

## Deployment posture
This gate introduces no network service, credentials, secrets, Edge Function, external webhook, or production adapter. Those require explicit release/security review.