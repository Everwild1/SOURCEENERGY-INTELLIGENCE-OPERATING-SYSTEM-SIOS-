# IBG-05 — Trade Finance Control Plane

## Purpose
IBG-05 governs trade-finance records without representing SourceEnergy, SETC, SIOS, GSF, or any internal registry as a bank, guarantor, issuing institution, confirming institution, or source of available credit.

## Dependencies
IBG-05 is downstream of IBG-01 institution verification, IBG-02 account/custody eligibility, IBG-03 payment orchestration, and IBG-04 treasury/liquidity controls. It cannot override any upstream fail-closed gate.

## Instrument lifecycle
Supported governed classes include letters of credit, standby letters of credit, bank guarantees, documentary collections, supply-chain finance and explicitly classified other instruments. Lifecycle states distinguish internal drafting/approval from external issuance, advice, confirmation, presentation, discrepancy, honour/refusal and closure.

External states require retained authoritative evidence and an external instrument reference. Issuing institutions must be VERIFIED and approved/active. A confirming institution, when represented as confirming, must independently satisfy the same institution gate.

## Documentary controls
Document requirements, presentations, discrepancies and waivers are separately recorded. Presented documents require evidence references. A discrepancy cannot be marked waived without waiver evidence, a deciding actor and decision timestamp.

## Exposure and collateral
Exposure records may reference IBG-04 treasury limits and liquidity reservations. Such references describe governance state; they do not create a credit facility, prove collateral perfection, establish a lien, or demonstrate bank availability. Collateral accounts used in executable instrument states must satisfy IBG-02 production eligibility.

## Claims and payment boundary
A trade-finance claim may reference an IBG-03 payment instruction. `PAYMENT_REQUESTED` requires that reference. IBG-05 never submits a bank payment directly and cannot bypass IBG-03 approvals, compliance, funding, route, idempotency or production controls. Provider-reported payment completion is still not settlement finality; IBG-06 is authoritative for reconciliation/finality.

## Strategic-enabler boundary
GSF's `STRATEGIC_INSTITUTIONAL_ENABLER` designation records relationship and credibility contribution only. It does not make GSF an issuing bank, confirming bank, advising bank, guarantor, SBLC provider, correspondent, custodian or settlement institution. Any such role requires the corresponding independently verified regulated-institution evidence and production relationship.

## Security and audit
Trade-finance tables are RLS-enabled and default-deny for public/anonymous/authenticated writes. Service-role access is constrained, while approvals and lifecycle history are append-only. Read-safe projections include explicit non-authority disclosure.

## Non-authority statement
A registry entry, website claim, dashboard logo, template, SWIFT-formatted document, relationship introduction, internal approval, PDF, screenshot, provider message, instrument number, or evidence upload does not by itself prove that a bank undertaking exists or is authentic, enforceable, funded, confirmed, transferable, payable, or settled.
