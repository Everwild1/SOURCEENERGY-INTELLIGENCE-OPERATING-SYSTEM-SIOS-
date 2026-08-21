# Capitalization Block / Empire Block Control Plane Architecture

## Executive mandate

The Capitalization Block is the horizontal financial control plane for the SourceEnergy Ecosystem. It governs capital lineage, treasury observability, institutional relationship state, interbank corridor state, fiat settlement orchestration, reconciliation, and evidence.

It does not convert a website listing into a banking relationship and does not displace the authoritative systems that own commercial workflow or economic finality.

## Bounded-context ownership

| Context | Authoritative responsibilities | Explicitly not authoritative for |
|---|---|---|
| SETC/SIOS | orchestration, canonical identity, policy, intelligence | external banking authority or settlement finality |
| Capitalization | commitments, facilities, allocations, treasury positions, interbank relationship state, fiat settlement orchestration, reconciliation | WIM trade workflow or Source Coin ledger effects |
| WIM Exchange | opportunities, market access, trade workflow, commercial transactions | treasury balances or settlement finality |
| Source Coin | Source Coin ledger, balances, supply, treasury issuance, finality | external fiat settlement |
| External fiat rail | external fiat clearing and finality | SourceEnergy governance and capital lineage |

## Core operating loop

```text
Capital Source
  -> Commitment / ECID
  -> Facility
  -> Allocation
  -> Treasury / Reserve
  -> Approval + Compliance
  -> Settlement Instruction
  -> External Fiat Rail OR Source Coin Domain
  -> Authoritative Confirmation
  -> Reconciliation
  -> Deployment
  -> WIM / Project / Asset / Program Outcome
  -> Wealth Ecology Measurement
  -> Audit and Intelligence
```

## Canonical identity strategy

The Capitalization schema stores an institutional projection with optional:

- `setc_organization_id`: canonical SETC identity reference
- `wim_organization_id`: WIM commercial projection reference
- external verified identifiers: LEI, BIC, routing or provider identifiers where legally appropriate

The projection never mints external authority. A `TARGET` record is simply a governed registry target.

## Relationship and connectivity split

Relationship state:

`TARGET -> IDENTIFIED -> CONTACTED -> DUE_DILIGENCE -> QUALIFIED -> AGREEMENT_PENDING -> CONTRACTED -> INTEGRATION_PENDING -> INTEGRATED -> LIVE`

Connectivity state:

`NOT_CONNECTED -> SANDBOX -> TEST -> CERTIFICATION -> PRODUCTION`

Suspended, degraded, offline, and terminated states remain explicit. A contractual relationship can exist without technical connectivity. A technical test connection cannot be represented as production.

## Capital lineage

Every capital commitment receives an Empire Capital ID:

`ECID-YYYY-NNNNNNNNN`

The ECID links commitment, facility, allocation, treasury account, settlement instruction, deployment, reconciliation, and outcome references. The lineage answers:

- where capital originated
- what agreement and restrictions govern it
- who approved allocation and settlement
- where it was held
- which rail moved it
- which authority confirmed finality
- which project, program, organization, or WIM transaction received it
- which evidence and outcomes resulted

## Security architecture

- `capitalization` is an internal schema.
- `anon` and `authenticated` receive no direct access to internal financial tables.
- `service_role` is used only by trusted server-side code and is never exposed to browsers.
- `capitalization_api` contains a deliberately narrow public-safe projection.
- RLS is enabled on every table.
- sensitive account references are opaque or masked references only.
- append-only event, history, snapshot, and audit tables reject update/delete mutation.
- material actions require approval evidence and separation of duties.
- production settlement remains blocked until the release gate is explicitly authorized.

## Public dashboard contract

The public Live Interbank Dashboard reads only from `capitalization_api.network_directory` and `capitalization_api.dashboard_metrics`.

It may display:

- institution display name
- institution type
- region/jurisdiction
- internal Dominion Cube and Relay Code
- relationship label
- connectivity label
- operational role
- last verification timestamp where approved
- an explicit disclosure boundary

It must never display:

- account references
- balances
- commitments
- internal evidence documents
- credentials or secrets
- unapproved settlement instructions
- a `LIVE` claim while the public-live-network release gate is disabled

## Integration contracts

### WIM to Capitalization

WIM may request settlement for a WIM transaction. It supplies:

- WIM transaction ID
- amount and currency
- buyer/seller organization projections
- compliance/trade references
- idempotency key and correlation ID

Capitalization may approve, restrict, or orchestrate settlement, but it does not rewrite WIM trade state directly. It emits a settlement status event for WIM to consume.

### Capitalization to Source Coin

Capitalization may issue a Source Coin settlement request reference. It never updates Source Coin balances, supply, treasury, or ledger rows. Finality requires an authoritative Source Coin confirmation.

### External fiat rail

Capitalization stores a settlement instruction and external confirmation reference. Finality belongs to the regulated external rail/provider. Credentials and raw bank account details remain in approved external secret/custody systems.

## Release gates

- `PRODUCTION_SETTLEMENT`: blocks SUBMITTED, ACCEPTED, and SETTLED transitions until enabled with evidence.
- `PUBLIC_LIVE_NETWORK_CLAIMS`: prevents public `LIVE` projections until enabled with evidence.

Enabling a gate requires an accountable authorization record and evidence reference. Infrastructure readiness alone is not authorization.

## Deployment sequence

1. Deploy schemas and default-deny grants.
2. Deploy capital, treasury, interbank, settlement, and audit tables.
3. Deploy public-safe projections.
4. Run validation SQL and Supabase advisors.
5. Seed current public-page entries only as targets, if approved.
6. Integrate SETC identity references.
7. Integrate WIM settlement requests.
8. Integrate Source Coin confirmation references.
9. Integrate external fiat adapters in sandbox/test only.
10. Collect independent security, compliance, legal, and operational evidence.
11. Authorize production gates through explicit governance action.
