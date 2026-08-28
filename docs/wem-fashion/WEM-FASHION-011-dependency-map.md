# WEM-FASHION-011 — SIOS Dependency Map

Status: Draft implementation contract

## Architecture decision

WEM Fashion Industry 4.0 is an additive bounded domain of the existing SourceEnergy Intelligence Operating System (SIOS). It does not create a separate repository, identity authority, marketplace, logistics ledger, settlement ledger, or capital authority.

## Reuse matrix

| WEM Fashion concern | Authoritative/reusable SIOS domain | Fashion disposition |
|---|---|---|
| Creator identity | `cruds.creators`, `seae.creator_profiles` | Reuse; add Fashion specialization only |
| Institutional identity | `public.setc_organizations` | Reuse canonical OID; no duplicate organizations |
| Creative work registry | `cruds.works`, `seae.work_registry` | Reuse for design/work identity and governance |
| Rights/interests | `seae.rights_interests`, `seae.licenses`, `seae.consent_records` | Reuse; Fashion records reference governed rights |
| Cultural assets | `seae.cultural_assets` | Reuse where cultural/heritage classification applies |
| Evidence/claims | `public.seg_evidence_items`, `public.seg_claims`, `public.seg_claim_evidence` | Reuse evidence authority |
| Commercialization | `public.hei_commercialization_cases`, `rw.commercialization_cases` | Reuse governed commercialization workflows |
| Royalties/revenue | `seae.revenue_events`, `seae.royalty_allocations` | Reuse; product transactions bind to revenue events |
| Market access | `wim.*`, `seae.wim_*_links`, `cruds.market_access_requests` | WIM remains authoritative for market/trade workflow |
| Supplier qualification | `public.hei_suppliers`, `public.hei_supplier_qualifications` | Reuse; Fashion adds capability/specification detail |
| Supply-chain nodes | `gsc.supply_nodes`, `gsc.corridor_portfolio` | Reuse network/corridor primitives |
| Logistics | `rgl.orders`, `rgl.shipments`, `rgl.tracking_events`, `rgl.customs_events`, `rgl.delivery_evidence` | RGL remains logistics authority |
| Capital readiness | `rw.capital_readiness_profiles`, `rw.capital_requests`, `rw.capital_referrals` | Reuse; no financing authority implied |
| Wealth Ecology | `seae.wealth_ecology_impact_links`, `cruds.impact_metrics`, `rw.impact_observations`, `rw.wealth_yield_records` | Reuse attribution/measurement infrastructure |
| Settlement | `wim.settlement_requests`, `seae.settlement_requests`, Source Coin/external rails | Reference/orchestration only; preserve finality boundary |

## Fashion-native semantic objects

A future migration may introduce a dedicated `fashion` schema only for semantics not already represented by SIOS:

- `fashion.brands` — Fashion-specific brand profile bound to `public.setc_organizations`.
- `fashion.designs` — Fashion design specialization bound to `cruds.works` / `seae.work_registry`.
- `fashion.collections` and collection/design membership.
- `fashion.materials` and material specifications.
- `fashion.product_models` — commercial style/model definition.
- `fashion.skus` — sellable variation (size/color/material/etc.).
- `fashion.product_instances` — serialized physical/digital product identity when instance-level traceability is required.
- `fashion.production_orders` and `fashion.production_batches` — apparel/accessory manufacturing semantics; links to SEAE production, qualified suppliers, and logistics.
- `fashion.lifecycle_events` — repair, resale, return, recovery, recycling, remanufacture, retirement.
- `fashion.wealth_outcome_links` only if the existing SEAE Wealth Ecology attribution bridge cannot express required Fashion object links without duplication.

## Objects explicitly not duplicated

Do not create Fashion-owned copies of creators, organizations, IP ownership, licenses, generic evidence, generic suppliers, WIM opportunities/transactions, RGL shipments, capital-provider decisions, settlement finality, or generic Wealth Ecology metrics.

## Rights-state rule

Fashion UI/API language may expose a simplified lifecycle such as `claimed`, `evidence_submitted`, `reviewed`, `verified`, `disputed`, `expired`, but persistence must map to the authoritative SIOS rights/evidence states. A Fashion registry entry does not itself create ownership, authorship, licensing rights, regulatory approval, financial entitlement, or settlement finality.

## Fashion RefleX boundary

Fashion RefleX is treated as a legacy venture/technology-commercialization lineage and evidence candidate until underlying technology mappings, agreements, contributors, licensing/ownership evidence, and commercialization authority are reconciled. No migration should seed a verified ownership claim solely from historical program references.

## Proposed migration gates

1. WF-DB-001: create Fashion schema, comments, reference/status controls, RLS baseline.
2. WF-DB-002: brand/design/collection bindings to SETC/CRUDS/SEAE.
3. WF-DB-003: product model/SKU/product-instance registry.
4. WF-DB-004: materials, qualified-supplier capabilities, manufacturing orders/batches.
5. WF-DB-005: WIM/GSC/RGL integration references; no duplicate execution records.
6. WF-DB-006: lifecycle/circularity events.
7. WF-DB-007: revenue/royalty/Wealth Ecology attribution bindings.
8. WF-DB-008: M1/RW readiness and commercialization bindings.
9. WF-DB-009: audit, acceptance tests, security/RLS verification.

No production migration is authorized by this document.

## Acceptance principles

- Existing canonical identity is referenced, never reminted.
- Rights and ownership remain evidence-governed.
- Every external execution domain retains its authority boundary.
- All new Fashion tables have RLS before client exposure.
- Migrations are additive and reversible where practical.
- Acceptance tests verify foreign keys, state constraints, RLS, boundary semantics, and non-duplication.
- Product lifecycle and Wealth Ecology attribution remain traceable to evidence.
