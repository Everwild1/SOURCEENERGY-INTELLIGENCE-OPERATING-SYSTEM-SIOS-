# Epic: Capitalization Block / Empire Block Financial Control Plane

## Objective

Establish the SourceEnergy Capitalization Block as the horizontal, governed control plane for capital lineage, treasury observability, institutional relationship state, interbank connectivity, settlement orchestration, reconciliation, risk, compliance, and audit across SETC/SIOS, WIM Exchange, external fiat rails, and Source Coin.

## Business outcome

The system must answer, with attributable evidence:

- Where did capital originate?
- Which agreement, restrictions, and authority govern it?
- Where is it held and who supplied the position evidence?
- Who approved allocation and settlement?
- Which external rail or Source Coin confirmation established finality?
- Where was capital deployed?
- Which WIM transaction, project, program, organization, or asset received it?
- Which reconciliation, risk, and Wealth Ecology outcomes followed?

## Non-negotiable authority boundaries

1. SETC/SIOS remains authoritative for orchestration and canonical institutional identity.
2. Capitalization is authoritative for capital commitments, treasury observations, interbank relationship state, fiat settlement orchestration, and reconciliation.
3. WIM Exchange remains authoritative for opportunities, trade, market access, commercial transactions, and commercialization workflow.
4. Source Coin remains authoritative for its ledger, balances, supply, treasury issuance, and finality.
5. External regulated fiat rails remain authoritative for fiat clearing and finality.
6. A website entry, Dominion Cube ID, Relay Code, database row, or application badge cannot create a banking relationship, custody authority, regulatory permission, account access, or settlement finality.
7. Production settlement and public live-network claims remain disabled until separately authorized with evidence.

## Delivery epics

### CAP-E01 — Bounded Context and Capital Lineage

Deliverables:

- `capitalization` and `capitalization_api` schema boundaries
- capital sources, commitments, facilities, allocations, deployments, and ECID lineage
- append-only lineage events
- destructive-deletion controls
- default-deny client access

Acceptance:

- every commitment has a unique `ECID-YYYY-NNNNNNNNN`
- every allocation/deployment references its upstream commitment
- capital lineage remains queryable without rewriting history
- `anon` and `authenticated` have no direct internal table privileges

### CAP-E02 — Institutional Registry and Evidence Lifecycle

Deliverables:

- financial-institution projection
- distinct relationship, connectivity, and verification states
- external identifier registry
- SourceEnergy internal-node identifiers
- relationship and connectivity history

Acceptance:

- `TARGET` records never render as partners or live connections
- `LIVE` requires verified institution state, evidence, and an active production node
- demotion of verification/connectivity requires relationship demotion first
- Dominion Cube and Relay Code remain explicitly internal identifiers

### CAP-E03 — Treasury, Reserve, Liquidity, Collateral, and FX

Deliverables:

- opaque treasury-account registry
- reserve classifications
- append-only treasury, liquidity, collateral, and FX position snapshots
- source authority, as-of timestamp, evidence, and reconciliation status

Acceptance:

- raw account numbers and credentials are rejected by contract
- every displayed position includes source authority and as-of timestamp
- snapshots cannot be updated or deleted
- public APIs expose no treasury values

### CAP-E04 — Interbank Corridors and Integration Endpoints

Deliverables:

- governed payment/settlement corridor model
- corridor participants and roles
- sandbox, test, certification, production, degraded, and offline states
- opaque credential/certificate references

Acceptance:

- production corridors require governance, compliance, evidence, and verification time
- no credential value is stored directly
- sandbox/test/certification are never labeled production

### CAP-E05 — Approval, Compliance, and Risk Controls

Deliverables:

- approval requests/actions
- self-approval rejection
- compliance cases/checks
- risk events and accountable treatment

Acceptance:

- requesters cannot approve or reject their own requests
- material decisions require evidence
- settlement submission requires approved request and cleared/not-required compliance case
- critical risks are visible to governance and audit roles

### CAP-E06 — Settlement Orchestration and Finality Boundary

Deliverables:

- replay-safe settlement instructions
- state-transition validation
- production release gate
- authoritative confirmations
- compensating corrections
- reconciliations

Acceptance:

- idempotency keys are unique
- invalid lifecycle skips are blocked
- production submission fails while the production gate is disabled
- Capitalization cannot self-confer finality
- Source Coin finality requires `SOURCE_COIN_DOMAIN`
- settled records require confirmation, evidence, and time

### CAP-E07 — WIM, Source Coin, and Fiat Adapter Contracts

Deliverables:

- versioned event envelope
- WIM settlement-request contract
- Source Coin confirmation contract
- external fiat confirmation contract
- outbox/inbox replay controls
- mTLS/signature boundary for adapters

Acceptance:

- Capitalization performs no direct WIM trade-state mutation
- Capitalization performs no Source Coin ledger/balance/supply mutation
- duplicate events cannot create duplicate execution records
- every event carries correlation and causation context

### CAP-E08 — Public Interbank Projection and Page Correction

Deliverables:

- sanitized public directory table
- safe dashboard metrics
- server-only refresh procedure
- public-page disclosure and status legend
- optional target-only import of current page entries

Acceptance:

- public table contains no financial, account, evidence-document, endpoint, credential, or settlement data
- public `VERIFIED_LIVE` is impossible while the public gate is disabled
- current website entries import only as `TARGET / NOT_CONNECTED / UNVERIFIED`
- public title remains “Interbank Network Registry & Connectivity Status” until live claims are authorized

### CAP-E09 — Capital Command Center Frontend

Deliverables:

- responsive route architecture
- role-scoped executive, capital, treasury, interbank, settlement, compliance, risk, and audit views
- accessible status labels and disclosures
- evidence and as-of metadata
- adverse-state and empty-state UX

Acceptance:

- browser has no internal-schema or service-role access
- optimistic UI is disabled for material governance and settlement actions
- every monetary value shows asset code, authority, as-of time, and reconciliation state
- authorization is enforced server-side, not only in the interface

### CAP-E10 — Release Assurance and Controlled Activation

Deliverables:

- migration validation evidence
- Supabase security/performance advisor evidence
- independent security, legal, compliance, privacy, and operational review
- sandbox/test/certification evidence
- recovery and emergency exercises
- configuration freeze manifest
- explicit gate authorization records

Acceptance:

- no unresolved critical findings
- material high findings have evidenced treatment and accountable risk disposition
- exact code SHA, migration head, environment, API contract, and configuration are frozen
- enabling one gate does not enable the other
- production and public claims remain NO-GO without explicit authorization

## Delivery sequence

`CAP-E01 -> CAP-E02 -> CAP-E03 -> CAP-E04 -> CAP-E05 -> CAP-E06 -> CAP-E07 -> CAP-E08 -> CAP-E09 -> CAP-E10`

Parallelization is permitted only after the authority boundaries and schemas in CAP-E01/CAP-E02 are accepted.

## Repository implementation

Branch: `feat/capitalization-control-plane`

Primary paths:

- `setc/capitalization/`
- `setc/capitalization/migrations/012_*.sql` through `016_*.sql`
- `.github/workflows/capitalization-ci.yml`
- `docs/CAPITALIZATION_BLOCK_IMPLEMENTATION_EPIC.md`

## Definition of done

The engineering release is complete when migrations, domain tests, static authority checks, API contracts, frontend contracts, and validation evidence are merged. That completion does **not** authorize production settlement or public live-network claims; those remain independent governance decisions represented by separate release gates.
