# SourceEnergy Ecology Block — Authority Constitution

The Ecology Block is the cross-domain orchestration and regenerative-value control plane of the SourceEnergy Intelligence Operating System. It coordinates relationships, lifecycle references, event lineage, impact feedback and regenerative cycles without replacing the authoritative bounded contexts it connects.

## Authority map

| Concern | Authoritative domain | Ecology posture |
|---|---|---|
| Institutional organization identity | SETC Organizations / Source Block | Typed reference only |
| Evidence, provenance and attestation | Source Block / approved evidence authority | Reference and lineage only |
| Commercial opportunity and trade workflow | WIM Exchange | Projection/reference only |
| Creative creator/work workflow | CRUDS Universe | Projection/reference only |
| HEI fiduciary, IP, procurement and project governance | HEI institutional domain | Projection/reference only |
| Physical supply-chain/logistics execution | GSC / RGL | Projection/reference only |
| Capital orchestration and treasury control | Capitalization Block | Projection/reference only |
| Fiat settlement finality | Approved external financial rail | Reference only |
| Source Coin ledger, balance, treasury and supply | Source Coin domain | Request/reference only |
| Cross-domain lifecycle and relationship graph | Ecology Block | Authoritative for Ecology projection state only |
| Wealth Ecology cross-domain aggregation | Ecology Block under governed methodology | Derived projection with lineage |
| Regenerative allocation recommendation | Ecology Block under governed policy | Recommendation/projection only; never settlement authority |

## Canonical operating loop

Authority/Evidence -> Creation/Research -> IP/Rights -> Commercialization -> Market -> Capital/Transaction -> Settlement Reference -> Impact -> Regenerative Allocation/Reinvestment -> New Research/Enterprise/Community Capacity

## Fail-closed invariants

1. Ecology never creates a second institutional organization master. Canonical institutional identity uses `SETC-OID-<32 lowercase hex>`.
2. A cross-domain reference never transfers ownership, fiduciary authority, regulatory status, approval, verification, custody or settlement finality.
3. Ecology cannot directly mutate WIM transactions, Source Coin balances/ledger/supply/treasury, HEI fiduciary records, CRUDS works, GSC/RGL logistics execution, or Capitalization treasury/finality records.
4. Every typed reference identifies its source domain, object type, source object identifier and authority posture.
5. References to institutional organizations use canonical SETC organization OIDs when an institutional actor is present.
6. Material cross-domain operations carry correlation, causation and idempotency semantics through the event-contract layer.
7. Provenance/evidence references identify evidence; they do not manufacture verification or legal truth.
8. Derived impact or regenerative-allocation projections retain source lineage and methodology/policy context.
9. Corrections preserve prior lineage rather than destructively rewriting authoritative source history.
10. Client database access remains fail-closed until explicit RLS/API publication policy is reviewed and tested.

## ECO-E01 scope

ECO-E01 establishes the canonical cross-domain identity and object-reference contract. It does not create the production `ecology` Supabase schema. Production DDL is gated to ECO-E04 after the reference, journey and event contracts are reviewed.

## Compatibility baseline

- WIM organization projections bind to canonical SETC organization OIDs.
- CRUDS objects remain CRUDS-owned and are referenced by their native identifiers.
- HEI records remain institution-controlled and are referenced by their native identifiers plus canonical organization OID where applicable.
- GSC/RGL logistics records remain execution-domain records and are referenced only.
- Capitalization records remain capital-control records and are referenced only.
- Source Coin request, product-journey and ledger identifiers remain Source Coin-owned; Ecology references never confer economic finality.

## Program references

- ECO parent: GitHub #229
- ECO-E01: GitHub #230
- ECO-E02: GitHub #231
- ECO-E03: GitHub #232
- ECO-E04: GitHub #233
