# SC-E12 — Independent Audit & Production Readiness

## Purpose
SC-E12 is a release-control and evidence gate. It does not itself activate Source Coin production economics.

## Required evidence
The release candidate must identify evidence for SC-E01 through SC-E11 plus:

- Supabase production/testnet separation
- RLS, Auth and privileged function review
- production key/custody readiness
- dependency/security scans
- privacy, legal and compliance evidence references
- rollback exercise
- emergency pause/recovery exercise

Evidence must identify the audited release SHA and configuration under review.

## Configuration freeze
Before authorization, freeze and record:

- release commit SHA
- migration head
- policy profile/version
- production network identifier
- infrastructure/environment manifest
- privileged function inventory

A material change after audit invalidates the affected evidence and requires re-review.

## Supabase production separation
Production readiness requires independent production secrets, service-role credentials and key/custody material. Testnet credentials, wallets, participant fixtures and synthetic genesis material must never be promoted into production.

Client roles remain prohibited from direct economic-table mutation. SECURITY DEFINER functions must be explicitly inventoried and reviewed. Realtime and projections remain non-authoritative.

## Residual-risk gate
No unresolved OPEN HIGH or CRITICAL finding may pass the release gate. Lower-severity findings require explicit disposition and evidence references. Risk acceptance is a governance act, not an engineering default.

## Activation separation
`audit_ready` and `activation_authorized` are separate states. Audit readiness alone cannot enable a capability.

An activation record must identify:

- approving authority
- authorization identifier
- evidence reference
- exact approved capability scope
- release/configuration being authorized
- effective operational limits

A capability outside that approved scope remains prohibited.

## Phased activation sequence
Recommended controlled sequence after independent authorization:

1. deploy production infrastructure with all economic feature flags false
2. verify monitoring, reconciliation, RLS and emergency controls
3. enable only the explicitly approved non-issuance capability scope
4. reconcile and observe before expanding scope
5. treat mint/burn as separately authorized privileged capabilities

## Rollback / emergency stop
Before any production authorization, operators must demonstrate:

- emergency pause procedure
- credential/key revocation procedure
- rollback or forward-fix deployment path
- ledger preservation and reconciliation process
- incident evidence capture
- governance escalation path

Rollback must never rewrite settled ledger history; corrections use governed compensating entries.

## Default posture
The audited codebase must continue to default to:

```text
SOURCE_COIN_MINT_ENABLED=false
SOURCE_COIN_BURN_ENABLED=false
SOURCE_COIN_PRODUCTION_ECONOMY_ENABLED=false
```

Changing those values is outside this engineering PR and requires a separate explicit governance authorization and controlled production operation.
