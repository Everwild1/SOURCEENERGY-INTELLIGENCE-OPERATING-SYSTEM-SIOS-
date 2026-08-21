# IBG-04 — Treasury & Liquidity Control Plane

Issue: #117

## Objective

Provide a governed liquidity and treasury decision layer over canonical IBG-02 treasury accounts and IBG-03 payment instructions without claiming bank-balance truth, custody finality, FX execution authority, or settlement finality.

## Canonical controls

- `liquidity_observations` retains balance/position provenance, observation time, source and evidence.
- `liquidity_reservations` allocates internal liquidity to a payment and prevents double allocation.
- `treasury_limits` records liquidity, account, counterparty, payment and outflow thresholds.
- `treasury_limit_overrides` requires maker/checker separation and governance evidence for approved exceptions.
- `liquidity_forecasts` stores time-bucket cash forecasts and methodology provenance.
- `fx_exposures` stores risk metadata only; it cannot authorize FX trading.
- `payment_funding_eligible()` is a fail-closed precondition check. It does not execute a payment.

## Funding boundary

A reservation requires an IBG-02 account that is `ACTIVE / VERIFIED / PRODUCTION_ELIGIBLE`, without an active account restriction, and sufficient unreserved liquidity from the latest evidence-backed observation. A payment is funding-eligible only when an active reservation covers its amount/asset on the source account and the IBG-03 instruction is approved/ready with compliance clear.

The IBG-03 execution gate remains authoritative for maker-checker approvals, verified institutions, production routes and submission. IBG-04 cannot bypass those controls.

## Authority boundary

`AVAILABLE` or internally unreserved liquidity is an internal treasury classification. It is not proof of legal title, bank confirmation, immediate withdrawability, custody finality, payment completion, or settlement finality.

Provider-reported payment completion remains non-final until IBG-06 reconciliation. External FX execution requires a separately governed market/provider capability.

## GSF boundary

GSF's `STRATEGIC_INSTITUTIONAL_ENABLER` designation may inform relationship management and diligence priority but cannot supply liquidity evidence, activate a treasury account, satisfy a production route, or override the `DUE_DILIGENCE / UNVERIFIED / NOT_CONNECTED / NO-GO` execution posture.

## Downstream

IBG-04 feeds IBG-05 Trade Finance and IBG-06 Settlement Reconciliation. Neither downstream lane may infer settlement finality from an IBG-04 observation, reservation, forecast or exposure record.
