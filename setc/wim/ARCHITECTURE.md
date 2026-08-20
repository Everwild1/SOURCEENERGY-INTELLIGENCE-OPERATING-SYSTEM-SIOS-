# WIM Exchange Architecture Boundary

WIM Exchange is the bounded commerce, market-access and exchange-infrastructure domain of the SourceEnergy Ecosystem.

## Authority map

| Concern | Authoritative domain | WIM posture |
|---|---|---|
| Institutional organization identity | SETC Organizations | Projection/reference only |
| Economic cluster commercial taxonomy | WIM/WITC after source verification | Authoritative only after verification gate |
| Research provenance | Source Block / approved research source | Reference and commercialization linkage |
| Commercial opportunity/trade workflow | WIM Exchange | Authoritative for WIM workflow state |
| Fiat settlement finality | Approved external financial rail | Reference/orchestration only |
| Source Coin ledger/economic effect | Source Coin domain services | Request/reference only |
| Banking/securities/regulatory authority | Applicable licensed/legal authority | Never conferred by WIM software |

## Fail-closed rules

1. A SETC organization identifier is accepted only in canonical `SETC-OID-<32 lowercase hex>` form.
2. A WIM organization must be verified and economically active before commercial activity is authorized.
3. Imported WITC taxonomy remains non-canonical until independent source verification is recorded.
4. A Source Coin request/reference never means settlement finality.
5. WIM code cannot directly mutate Source Coin balances, supply, treasury, or ledger state.
6. Direct client database access remains default-deny until an explicit RLS/API authorization design is approved and tested.

## Deployment baseline

The authoritative integration backend currently hosts the deployed `wim` schema. Repository migrations and domain contracts must remain reconcilable with that deployed schema. Database deployment does not, by itself, satisfy repository engineering or release assurance.

## Program references

- WIM program: GitHub #89
- WIM-E01: GitHub #90
- Canonical architecture specification: SourceEnergy Ecosystem Google Drive
