# Capitalization Block Frontend Route Architecture

## Product boundary

The frontend is an observability and governed-action layer over server-side APIs. It must not connect a browser directly to internal `capitalization` tables or use a Supabase `service_role` credential. Public pages read only the approved `capitalization_api` projection.

## Route map

| Route | Audience | Purpose | Primary data | Material actions |
|---|---|---|---|---|
| `/our-services/live-interbank-dashboard/` | Public | Public-safe institution and node registry | `GET /v1/public/network-directory`, `GET /v1/public/dashboard-metrics` | None |
| `/capitalization` | Authenticated | Capital Command Center shell | Aggregated server API | None |
| `/capitalization/overview` | Executive, governor, auditor | Commitments, allocations, liquidity posture, settlement exceptions, risk | Server-composed read model | None |
| `/capitalization/commitments` | Capital operations | Capital sources, commitments, facilities, ECID lineage | Commitment APIs | Create draft, route for approval |
| `/capitalization/commitments/:ecid` | Authorized staff | End-to-end capital lineage and evidence references | `GET /v1/capitalization/commitments/{ecid}` | Governed correction request |
| `/capitalization/allocations` | Capital operations, approvers | Allocation pipeline and restrictions | Allocation APIs | Submit/approve/restrict |
| `/capitalization/deployments` | Capital operations, WIM liaison | Capital deployment to projects, programs, organizations, and WIM transactions | Deployment APIs | Create/route/reconcile |
| `/capitalization/treasury` | Treasury | Accounts, reserves, liquidity, collateral, and FX snapshots | Treasury APIs | Snapshot ingestion, exception escalation |
| `/capitalization/treasury/accounts/:accountReference` | Treasury, auditor | Sourced position history and reconciliation state | Treasury position APIs | Reconcile, restrict |
| `/capitalization/interbank` | Network operations, compliance | Institution relationships, network nodes, corridors, and connectivity | Interbank APIs | Advance relationship state, manage sandbox/test status |
| `/capitalization/interbank/institutions/:institutionReference` | Network operations, auditor | Relationship, verification, identifiers, nodes, and evidence timeline | Institution APIs | Due-diligence and status actions |
| `/capitalization/interbank/corridors/:corridorReference` | Network, treasury, compliance | Corridor participants, limits, environment, and evidence | Corridor APIs | Certify/restrict/suspend |
| `/capitalization/settlements` | Settlement operations | Instruction queue and lifecycle | Settlement APIs | Create draft, submit after approvals |
| `/capitalization/settlements/:instructionReference` | Settlement operations, approver, auditor | Instruction, approvals, compliance, confirmation, and reconciliation | Settlement APIs | Approve, submit, reconcile, correct |
| `/capitalization/compliance` | Compliance | KYB/AML/sanctions/corridor and source-of-funds cases | Compliance APIs | Clear/restrict/deny with evidence |
| `/capitalization/risk` | Risk, governor | Credit, liquidity, FX, operational, cyber, legal, and concentration risks | Risk APIs | Treat/escalate/accept with authority |
| `/capitalization/audit-lineage` | Auditor, governor | Immutable lineage, state history, outbox/inbox, and evidence trail | Audit APIs | Evidence export only |
| `/capitalization/governance/release-gates` | Governor, independent approver | Production settlement and public-live-claim gates | Governance APIs | Evidence-backed enable/disable only |
| `/capitalization/admin/public-projection` | Communications governor, system admin | Preview and refresh public-safe projection | Projection API | Refresh; never bypass gate |

## Public dashboard behavior

Until `PUBLIC_LIVE_NETWORK_CLAIMS` is enabled with independent evidence, the public page title should be **Interbank Network Registry & Connectivity Status**. The existing URL may remain stable for search continuity.

The public table fields are limited to:

- institution display name
- institution type
- jurisdiction or region
- SourceEnergy node ID
- Dominion Cube ID, labeled as an internal identifier
- Relay Code, labeled as an internal identifier
- operational role
- relationship label
- connectivity label
- approved verification timestamp
- disclosure

The public page must never render account references, balances, commitments, evidence documents, API endpoints, credentials, settlement records, risk cases, or private identifiers.

## Status presentation contract

### Relationship labels

| Internal state | Public treatment |
|---|---|
| `TARGET` through `AGREEMENT_PENDING` | `Registry target; no verified institutional relationship is asserted` |
| `CONTRACTED`, `INTEGRATION_PENDING`, or `INTEGRATED` with evidence | `Evidence-backed relationship; production status not publicly asserted` |
| `LIVE` without public claim gate | `Evidence-backed relationship; public live claim withheld` |
| `LIVE` with verified institution, production node, evidence, and enabled gate | `Verified live connection` |
| `SUSPENDED` or `TERMINATED` | Removed from the public projection unless governance explicitly publishes a historical notice |

### Connectivity labels

`NOT_CONNECTED`, `SANDBOX`, `TEST`, `CERTIFICATION`, `PRODUCTION`, `DEGRADED`, and `OFFLINE` must remain distinct. UI copy may not collapse sandbox, test, or certification into “connected.”

## Authorization matrix

| Capability | Viewer | Capital Ops | Treasury | Network Ops | Compliance | Approver | Auditor | Governor | Adapter |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Read authorized summaries | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Scoped |
| Create commitment/allocation draft | No | Yes | No | No | No | No | Read | Yes | No |
| Ingest treasury snapshot | No | No | Yes | No | No | No | Read | Yes | Scoped |
| Change relationship/connectivity state | No | No | No | Yes | Review | Approve where required | Read | Yes | Scoped test status only |
| Clear compliance case | No | No | No | No | Yes | No | Read | Escalation only | No |
| Approve material request | No | No | No | No | No | Yes, never own request | Read | Yes, never own request | No |
| Submit settlement | No | No | Yes | No | Clearance | Approval prerequisite | Read | Emergency restriction only | Scoped adapter execution |
| Enable release gate | No | No | No | No | Evidence input | Independent approval | Read | Yes with evidence | No |

## Route guards

1. Every protected route requires a valid SETC/SIOS-issued identity and current authorization claims.
2. Material actions require step-up authentication and a fresh policy decision.
3. Approval UI must hide and server-side reject approve/reject actions when the current actor requested the action.
4. Production submission UI remains disabled while `PRODUCTION_SETTLEMENT` is false; the server independently enforces the same rule.
5. A public `VERIFIED_LIVE` badge is impossible while `PUBLIC_LIVE_NETWORK_CLAIMS` is false.
6. The browser never receives `service_role`, external provider credentials, private keys, custody keys, or raw bank-account data.
7. Monetary values display asset code, source authority, as-of time, reconciliation state, and evidence availability.
8. Corrections create compensating records; the UI never offers destructive history deletion.

## State management and live updates

- Public directory updates are served from the sanitized projection, not directly from internal tables.
- Internal command-center updates should use a server-managed event stream or broadcast channel after authorization.
- Realtime database-change subscriptions must not be opened against internal financial tables from browsers.
- Every command carries `Idempotency-Key`, `X-Correlation-Id`, and, when applicable, `X-Causation-Id`.
- Optimistic UI is prohibited for approvals, settlement submission, release-gate changes, and finality confirmation.

## Implementation sequence

1. Build the public registry against mocked `PublicNetworkDirectoryEntry` objects.
2. Implement authenticated shell and route guards.
3. Add read-only commitment, treasury, interbank, settlement, compliance, and audit views.
4. Add draft commands and evidence attachment references.
5. Add approval and compliance actions with separation-of-duties checks.
6. Add sandbox/test adapter status and reconciliation flows.
7. Add governance gate screens.
8. Perform accessibility, responsive, authorization, and adverse-state QA.
9. Enable production features only after independent release authorization.
