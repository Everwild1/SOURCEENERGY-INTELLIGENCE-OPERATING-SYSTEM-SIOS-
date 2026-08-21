# IBG-03 — Payment Orchestration Control Plane

## Authority boundary

IBG-03 governs payment intent, approval, compliance clearance, route eligibility, provider submission, and provider-reported execution state. It does not create bank money, custody authority, payment-system membership, or settlement finality.

A payment instruction is an internal control-plane object. `COMPLETED` means only that the configured provider/rail has reported completion. Reconciled settlement finality belongs exclusively to IBG-06.

## Core controls

1. Every payment has a unique payment reference and idempotency key.
2. Amounts must be positive and identify an asset/currency.
3. Every payment requires at least two approvals before approval/execution states.
4. Compliance must be `CLEAR`; any active hold fails closed.
5. `READY` or later requires an IBG-02 source account that is `ACTIVE / VERIFIED / PRODUCTION_ELIGIBLE`.
6. The source account's custodian institution must be `VERIFIED` and `APPROVED` or `ACTIVE`.
7. Provider submission additionally requires explicit production execution enablement and an evidence-backed production network node.
8. Terminal states cannot be reopened by ordinary state transition.
9. Approval and state-history records are append-only.
10. Application-facing projections exclude credentials and sensitive account identifiers.

## State model

`DRAFT` → `PENDING_APPROVAL` → `APPROVED` → `READY` → `SUBMITTED` → `ACCEPTED` / `PROCESSING` → `COMPLETED`

Controlled alternatives include `ON_HOLD`, `REJECTED`, `CANCELLED`, `FAILED`, `RETURNED`, and `EXPIRED`.

## Maker-checker boundary

The database requires a minimum approval count of two. Service/application policy should additionally require distinct actors and appropriate approval roles for the applicable payment class, amount, jurisdiction, and risk tier. Approval records are immutable; a new governance event is required to represent a changed decision.

## Idempotency and duplicate protection

`idempotency_key` is unique at the control-plane boundary. A retry using the same business operation must resolve to the existing payment instruction rather than creating a second payment. Provider-side idempotency must also be used where the external rail supports it.

## Compliance holds

KYC/KYB, AML, sanctions, fraud, limit, documentation, or manual-review holds block advancement into approval/execution states while active. Release of a hold does not itself approve a payment.

## Routing

IBG-03 abstracts route type from route authority. A route labelled `SWIFT`, `ACH`, `SEPA`, `LOCAL_CLEARING`, or another rail is not executable merely because that label exists. Submission requires a verified institution and an active evidence-backed `PRODUCTION` network node.

## GSF boundary

GSF Banking is currently `DUE_DILIGENCE / UNVERIFIED / NOT_CONNECTED / NO-GO`, notwithstanding its strategic `STRATEGIC_INSTITUTIONAL_ENABLER` designation. Therefore:

- GSF cannot be selected as an executable IBG-03 production route.
- advertised SWIFT, DuitNow, FPX, SEPA, ACH, PACS.008, treasury, card, or trade-finance capabilities do not satisfy route eligibility;
- Issue #115 must resolve the settlement/sponsor institution contradiction with authoritative evidence before any related route can be considered for production qualification;
- strategic credibility/access contribution cannot override payment execution controls.

## Settlement boundary

Provider acknowledgements, accepted messages, processing states, transaction identifiers, and provider-reported completion are evidence inputs only. IBG-06 must reconcile external statements/messages/ledger evidence before SourceEnergy represents a payment as settled/final.

## Out of scope

- liquidity optimization and cash positioning — IBG-04;
- trade-finance instrument execution — IBG-05;
- reconciled settlement finality — IBG-06;
- private credentials, signing keys, PINs, secrets, or raw banking authentication material.
