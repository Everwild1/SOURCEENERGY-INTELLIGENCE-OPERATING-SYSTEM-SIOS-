# Source Coin SC-E09 Threat Model

## Protected assets

Ledger and supply integrity, treasury balances, organization-wallet bindings, authorization and compliance evidence, privileged credentials, settlement finality, domain-event provenance, deployment artifacts, and confidential participant data.

## Trust boundaries

1. Participant/client -> API gateway/server boundary.
2. SETC service -> Source Coin domain boundary.
3. Source Coin service -> Supabase Postgres boundary.
4. Source Block/event producer -> settlement/reward request boundary.
5. Transactional outbox -> event consumer boundary.
6. Administrative/governance principal -> privileged economic control boundary.

## Primary threats and controls

| Threat | Required control |
| --- | --- |
| Unauthorized mint/burn | Production-off feature gates; no participant API; dedicated privileged authorization; SC-E12 gate |
| Direct ledger mutation | Default-deny RLS; server-only execution functions; revoke client table/function mutation |
| Replay/double execution | Unique idempotency keys; inbox deduplication; atomic transaction boundary |
| Supply divergence | Executable supply reconciliation invariant and CI tests |
| Transfer imbalance | Equal debit/credit invariant and atomic ledger posting |
| Cross-organization access | Canonical SETC organization identity; authorization checks; RLS policy tests |
| Malicious/compromised service | Least-privilege service identities; audit trail; bounded database grants |
| SECURITY DEFINER abuse | Explicit function review; fixed search_path; narrow EXECUTE grants; no dynamic SQL for economic authority |
| Event duplication | Consumer inbox uniqueness and idempotent handlers; transport never becomes economic authority |
| Policy dependency outage | Mandatory controls fail closed |
| Insider abuse | Separation of duties; privileged-action logging; threshold/quorum controls where applicable |
| Secret leakage | Service-role/signing secrets external to client code and repository; rotation/recovery procedures |
| Emergency incident | Governed PAUSED state; evidence-preserving recovery and controlled release |

## Supabase hardening requirements

- Economic tables exposed through Supabase must have RLS enabled and default-deny posture.
- `anon` and `authenticated` roles must not receive direct ledger, treasury, supply, mint, burn, or privileged function mutation rights.
- Service-role credentials are server-side only and never embedded in browser/mobile bundles.
- `SECURITY DEFINER` economic functions require fixed `search_path`, explicit input validation, least-privilege ownership/grants, and code review as privileged economic code.
- Realtime is permitted for selected projections/events only; Realtime messages never authorize economic execution.
- Migrations changing ledger constraints, grants, RLS, privileged functions, supply, or treasury semantics are security-sensitive changes.

## Emergency lifecycle

`ACTIVE -> PAUSED` blocks new economic execution while preserving reads, audit evidence, reconciliation, and incident investigation as approved. Release from pause requires accountable authorization, root-cause treatment, reconciliation, and controlled restart evidence.

## Production blocker policy

Unresolved critical findings block production. High findings require remediation or explicit treatment under the SC-E12 risk gate. Passing CI does not itself authorize production activation.
