# ECO-PH-04 — Recovery, Rollback & Operational Resilience Certification

## Authority boundary
Recovery restores Ecology-owned orchestration/projection capability. It never recreates, substitutes for, or overwrites authoritative source-domain facts, Source Coin ledger state, settlement finality, treasury authority, or external institutional approvals.

## Failure posture
- Healthy required dependencies: normal non-authoritative Ecology orchestration.
- Degraded dependencies: read-only projection/diagnostic posture.
- Unavailable required dependency: fail closed.
- Source Coin release blocked: fail closed for any flow requiring Source Coin; degraded mode cannot bypass its release gate.
- Missing dependency-health evidence: fail closed.

## Recovery objectives
Ecology projection state and append-only correction lineage must be recoverable from approved backups plus authoritative source references. Recovery must preserve correlation, evidence and correction lineage. Source facts are re-referenced or re-projected; they are never rewritten by Ecology.

## Database recovery procedure
1. Freeze Ecology writers and gateway material-request acceptance.
2. Record incident identifier, affected component, last known-good migration and backup evidence.
3. Restore into an isolated recovery target first.
4. Validate schema migrations, RLS/private-schema privileges, PH-01 domain→authority constraints, and PH-02 append-only correction privileges.
5. Reconcile Ecology references against authoritative source systems without mutating those systems.
6. Prefer additive forward-fix migrations. Destructive rollback requires explicit governance approval and must never delete correction history.
7. Re-enable projection writes only after validation evidence is attached to the recovery exercise.
8. Re-enable material gateway requests only after authentication, authorization, shared replay/rate state and audit dependencies are healthy.

## Backup evidence requirements
A production certification packet must identify backup timestamp, retention class, restore target, restore duration, validation results, migration version, row-count/checksum evidence where appropriate, operator/approver, and incident/exercise reference. Documentation of a procedure is not proof that a restore exercise occurred.

## Gateway degraded mode
The production adapter must bind PH-03 replay/rate semantics to durable shared state. If that state, authentication/authorization, audit logging, or required authority health is unavailable, material requests fail closed. Read-only diagnostics may remain available if they do not create source-domain effects.

## Incident severity
- SEV-1: suspected authority escalation, financial/settlement effect without authoritative confirmation, security compromise, or correction-history integrity loss. Immediately fail closed.
- SEV-2: gateway/replay/audit dependency outage or projection integrity concern. Suspend material requests; read-only where safe.
- SEV-3: non-authoritative projection freshness/dependency degradation. Read-only/degraded posture.

## Release evidence
ECO-E09 may mark recovery/rollback satisfied only after an actual controlled restore/recovery exercise has produced evidence. This code/documentation establishes the contract and testable fail-closed behavior but does not fabricate operational exercise evidence.

## Shared backend security
Known PostGIS/shared-backend advisories remain a separate compatibility-reviewed security tranche. ECO-PH-04 makes no PostGIS changes.
