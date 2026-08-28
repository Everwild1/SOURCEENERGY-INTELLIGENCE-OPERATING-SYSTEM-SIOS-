# ECO-E02 — Canonical Ecology Journey Graph

## Purpose

The Ecology Journey Graph coordinates value creation across SourceEnergy bounded domains while preserving each source domain's authority. A journey is a graph of typed references, not a new master record for research, IP, commercialization, markets, capital, logistics, settlement, or impact.

## Canonical cycle

Authority/Evidence → Research/Creation → IP/Rights → Commercialization → Venture/Enterprise → Market Opportunity → Capital Readiness → Capital → Transaction → Settlement Reference → Impact → Regenerative Allocation → Reinvestment → next Research/Enterprise/Community Capacity cycle.

The graph may omit stages that do not apply and may branch. Reinvestment may point back to new research, enterprise, infrastructure, community, human-capital, or ecological-capacity objects.

## Lifecycle dimensions

A single `stage` must not be overloaded to represent every readiness question. Nodes can carry source-backed states in parallel dimensions:

- research/IP;
- commercialization;
- market readiness;
- capital readiness;
- regulatory;
- deployment;
- impact.

The source object remains authoritative for each state.

## Domain mappings

| Domain | Example journey references | Ecology posture |
|---|---|---|
| SETC / Source Block | organization, evidence, research asset, provenance anchor | reference/projection |
| HEI | research project, IP asset, commercialization case, revenue waterfall | reference/projection |
| CRUDS | creator work, provenance, commercialization project | reference/projection |
| WIM | opportunity, market-access workflow, transaction, impact record | reference/projection |
| GSC / RGL | corridor, supply node, shipment/logistics execution | reference/projection |
| Capitalization | capital-readiness object, allocation/settlement reference | reference/projection |
| Source Coin | product journey, request, ledger-event/settlement reference | reference only; never finality by inference |

## Invariants

1. Journey nodes contain typed `EcologyObjectReference` values; they do not copy source records.
2. Journey edges express relationships and lineage, not transfer of ownership or authority.
3. A settlement reference never proves settlement finality.
4. A Source Coin reference never permits Ecology to mutate balances, ledger, treasury, or supply.
5. A WIM transaction reference never permits Ecology to mutate WIM transaction state.
6. HEI/CRUDS/GSC/RGL/Capitalization authority remains in its source bounded context.
7. Multiple lifecycle dimensions may coexist without collapsing into one stage value.
8. Corrections and later ECO persistence should preserve historical lineage rather than destructively rewrite prior edges.
9. Regenerative allocation is an intelligence/governance projection until an authoritative capital or economic domain separately approves and executes it.

## ECO-E03 handoff

Each persisted journey mutation/event will later use the Ecology Event Envelope with event ID, producer/source authority, correlation, causation, idempotency, typed object references, provenance/evidence, timestamps, classification, and replay semantics.

## ECO-E04 handoff

The future `ecology` Supabase schema may persist journey projections, nodes, edges, lifecycle-state projections, value-flow references and impact/reinvestment lineage. It must not duplicate the authoritative business objects listed above.
