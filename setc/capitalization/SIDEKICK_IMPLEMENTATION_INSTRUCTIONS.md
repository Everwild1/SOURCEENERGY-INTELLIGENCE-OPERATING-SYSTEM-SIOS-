# Sidekick Implementation Instructions

## Mission

Implement the Capitalization Block repository overlay without weakening its authority boundaries, release gates, evidence requirements, or default-deny posture.

## Branch and file placement

1. Create branch `feat/capitalization-control-plane` from the current protected integration baseline.
2. Copy all paths from `repo-overlay/` into the repository root.
3. Do not renumber existing migrations. The Capitalization sequence begins at `012` because the current SETC migration head is `011`.
4. Open a draft pull request and link the Capitalization implementation epic.

## Mandatory implementation rules

- Do not create direct foreign-key or mutation authority into Source Coin ledger tables.
- Do not update WIM trade or transaction state from Capitalization code.
- Do not claim any named institution is contracted, integrated, or live based only on the website.
- Do not seed a production endpoint, production corridor, live relationship, or verified institution.
- Do not expose the internal `capitalization` schema through the Data API.
- Do not use `service_role` in frontend code.
- Do not store raw account numbers or credentials.
- Do not bypass approval, compliance, idempotency, transition, finality, or release-gate checks.
- Do not implement destructive deletion for financial, lineage, evidence, confirmation, or audit records.

## Engineering sequence

1. Add Python domain package and run unit tests.
2. Add migrations 012-015 and static checks.
3. Review SQL against the current command-backend schema.
4. Deploy to an isolated development/staging environment.
5. Run `validation.sql` and Supabase advisors.
6. Implement server API from `openapi.yaml`.
7. Build protected frontend routes from `FRONTEND_ROUTES.md`.
8. Build public registry against the sanitized projection.
9. Apply optional migration 016 only after governance approves the public-page correction.
10. Complete independent release assurance before any production gate change.

## Required pull-request evidence

- test output
- static artifact-check output
- migration dry-run output
- schema diff
- RLS/grant matrix
- security/performance advisor output
- OpenAPI validation output
- screenshots for public, empty, target-only, evidence-backed, gated-live, restricted, degraded, and offline states
- authorization tests proving self-approval and production-gate bypass fail
- replay tests proving duplicate commands/events do not duplicate economic execution
- explicit statement that both release gates remain false

## Merge gate

The pull request may merge when engineering and security controls pass. Merge does not activate production settlement or authorize public live-network claims.
