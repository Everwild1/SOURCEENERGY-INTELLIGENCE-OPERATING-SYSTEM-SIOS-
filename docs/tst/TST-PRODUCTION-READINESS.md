# TST Production Readiness & Go/No-Go Package

## Status
WP01-WP14 are merged. This package governs the transition from validated software architecture to a controlled pilot and eventual production operation.

## Mandatory go-live gates
A production GO requires documented PASS for every gate below. A failed or unknown gate is a NO-GO.

1. Database migration replay: all TST migrations apply cleanly from an empty supported PostgreSQL/Supabase-compatible database.
2. Regression: every TST contract test passes in sequence against the complete migration chain.
3. Access control: RLS enabled on governed tables; anon/authenticated have no unintended direct grants; service-role credentials are server-side only.
4. Segregation of duties: initiator, final approver, payment executor, reconciler, compliance validator, and trustee controls are exercised with negative tests.
5. Financial integrity: contribution, allocation, commitment, distribution, payment, settlement and reconciliation totals are deterministic and no duplicate payment path exists.
6. Beneficiary governance: eligibility, compliance, conflict, related-party and independent-approval controls pass.
7. Evidence integrity: evidence identity is immutable, audit events are append-only, and hash-chain verification passes.
8. Assurance: reporting period close is blocked until reconciliation, evidence, audit-chain and trustee-attestation prerequisites are complete.
9. Oversight: high/critical open findings and overdue active compliance obligations block readiness.
10. Backup/recovery: database backup, restore, evidence-object recovery and key/secret recovery procedures are tested in a non-production environment.
11. Observability: migration failures, authorization failures, payment exceptions, reconciliation exceptions, audit-chain failures and compliance blockers have operational alert owners.
12. External authority: legal/tax/fiduciary/regulatory/banking requirements applicable to the actual operating entity, jurisdiction, fund structure and payment rails are documented and approved by the appropriate external professionals/providers.

## Controlled pilot
The first pilot MUST use non-production or nominal-value transactions unless external counsel, fiduciary governance and banking/payment providers have expressly authorized otherwise.

Pilot scenario: election -> calculation -> contribution -> restricted fund -> allocation -> eligible beneficiary -> distribution -> trustee approval -> treasury release -> payment -> settlement -> independent reconciliation -> evidence package -> trustee attestation -> assurance package -> compliance review.

Capture correlation IDs, actor IDs, timestamps, evidence hashes, audit hashes, external references and exception outcomes. Exercise at least one denied self-approval, denied conflicted approval, duplicate-payment rejection, reconciliation exception/HOLD, and compliance-readiness blocker.

## Operational roles
System Owner: accountable for service availability and deployment approval.
Trustee: stewardship/fiduciary approval within documented authority.
Treasury: executes authorized payments only.
Reconciler: independent settlement reconciliation.
Compliance Validator: validates remediation and compliance readiness.
Security Administrator: secrets, access, incident response and privileged-role reviews.
External Professionals/Providers: supply legal, tax, fiduciary, audit, regulatory and banking determinations where applicable.

## Incident / rollback
On integrity, authorization, payment, reconciliation or audit-chain anomaly: stop new distributions, place affected transactions on HOLD, preserve evidence, revoke compromised credentials, record a control finding, investigate, remediate, validate independently, and resume only after documented approval. Database rollback must not erase immutable audit/evidence history; use corrective forward transactions where financial/audit history is involved.

## Certification boundary
CI PASS means the repository contract passed its automated tests. It is not an external audit opinion, legal determination, tax opinion, banking authorization, fiduciary certification, or regulatory approval.

## Production decision
GO only when every mandatory gate is PASS and named accountable approvers have recorded the decision. Otherwise status remains NO-GO / PILOT ONLY.
