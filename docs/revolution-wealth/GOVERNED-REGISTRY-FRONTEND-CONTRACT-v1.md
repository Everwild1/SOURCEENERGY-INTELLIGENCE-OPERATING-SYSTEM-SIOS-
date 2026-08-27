# Revolution Wealth Governed Registry Frontend Contract v1.0

Status: implementation baseline
Backend authority: SourceEnergy-command-backend Supabase project
Schema: `rw`
Security authority: `rw_private`

## Purpose

This contract defines the first frontend/API boundary for the Revolution Wealth institutional capital registry. Frontend code MUST consume governed read models rather than directly treating public website copy or internal narrative documents as transactional truth.

## Authentication and authorization

1. All registry application routes require Supabase Auth.
2. Authorization is enforced by PostgreSQL RLS, not UI state.
3. Production role binding is service-operated through `rw_private.grant_registry_access(...)` and `rw_private.revoke_registry_access(...)`.
4. Anonymous access to governed registry views is prohibited.
5. The frontend MUST NOT contain or expose a Supabase service-role key.
6. UI authorization is advisory only; database RLS remains authoritative.

Institutional roles:
- `administrator`
- `investment_reviewer`
- `governance_reviewer`
- `organization_participant`
- `auditor`

## Governed read models

### `rw.registry_fund_overview`
Primary fund dashboard source.

Fields include registry identity, legal/display name, fund type, jurisdiction, stated target amount, currency, lifecycle status, verification status, effective date, managing organization, and aggregate vehicle/project/asset counts.

### `rw.registry_capital_activity`
Capital activity source.

Fields include event type, amount, currency, occurrence timestamp, verification status, fund/project/asset/organization references, and external reference.

The UI MUST NOT label an amount as committed, funded, available, deployed, returned, or valued unless the corresponding `event_type` and `verification_status` support that representation.

### `rw.registry_claim_overview`
Institutional claim/governance source.

Claims must visibly retain their governance status. The application must distinguish at minimum:
- `documented_internal`
- `pending_verification`
- `verified`
- `target`
- `proposed`
- `historical`
- `superseded`

`documented_internal` MUST NOT be rendered as independently verified.

## Initial route model

Recommended application routes:

- `/revolution-wealth` — institutional overview
- `/revolution-wealth/funds` — governed fund registry
- `/revolution-wealth/funds/:registryCode` — fund detail
- `/revolution-wealth/capital-activity` — authorized capital activity
- `/revolution-wealth/claims` — reviewer/auditor governance view

## Frontend state requirements

Every data-bearing screen must implement:
- authenticated loading state
- unauthorized/empty state without leaking row existence
- data unavailable/error state
- verification-status treatment
- explicit last-refreshed timestamp where appropriate

Do not infer zero capital, zero assets, or zero projects from an RLS-empty response. An empty authorized result may represent lack of access rather than absence of records.

## Canonical hierarchy

`Organization -> Fund -> Vehicle -> Project -> Asset -> Capital Event -> Outcome`

WIM opportunity/project identifiers may be attached as cross-domain references, but WIM remains the market/opportunity layer and does not become the authoritative fund ledger.

## Security boundary

Client applications use the authenticated Supabase client and governed `rw` read models. Administrative role grants/revocations are server/service operations only. Raw registry-table mutation should not be introduced into the public frontend in v1.

## Production activation dependency

The database remains fail-closed until a genuine Supabase Auth identity is created and deliberately bound to an institutional role. Do not create synthetic production identities to bypass this gate.
