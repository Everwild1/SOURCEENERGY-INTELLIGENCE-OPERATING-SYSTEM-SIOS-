# TST Pilot Evidence Manifest

Pilot ID: TST-PILOT-001
Status: CONTROLLED PILOT EXECUTED — CONDITIONAL PASS
Production authorization: NONE / NO-GO
Environment: isolated Supabase pilot branch `ibtovlchjbsazciwmhlw`
Repository engineering baseline: `b85dbb7cde05ec9c44a8a14e230ae17ddcd6510a`

| Gate | Required evidence | Status |
|---|---|---|
| Repository baseline | main engineering baseline + controlled-pilot branch | PASS |
| Full regression | successful repository full-regression workflow | PASS |
| Role segregation | Initiator, Trustee, Treasury Executor, Independent Reconciler, Compliance Validator, Auditor | PASS |
| Positive transaction chain | simulated contribution → allocation → distribution → settlement → reconciliation | PASS |
| Self-approval denial | initiator cannot final-approve | PASS |
| Approver/executor denial | final approver cannot execute payment | PASS |
| Duplicate payment denial | unique distribution/idempotency payment controls | PASS |
| Executor/reconciler denial | executor cannot reconcile own payment | PASS |
| Reconciliation HOLD | TST-PILOT-002 $0.01 mismatch produced EXCEPTION/HOLD | PASS |
| Evidence integrity | pilot evidence stored with SHA-256 identity | PASS |
| Audit integrity | `verify_audit_chain = true` after remediation and assurance issuance | PASS |
| Trustee assurance | FINAL statement + pilot-qualified attestation + `TST-PILOT-ASSURANCE-001` ISSUED | PASS |
| Compliance blocker | HIGH reconciliation-variance finding exercised | PASS |
| Remediation closure | evidence-backed remediation independently validated; finding CLOSED | PASS |
| TST security advisor | no TST-specific RLS-without-policy findings after hardening | PASS |
| Backup/restore | isolated backup + restore + post-restore audit verification | PENDING — connector does not expose backup/restore operation |
| Observability | named alert owners, escalation route and response objectives with runtime evidence | PENDING |
| Parent migration reproducibility | fresh branch migration chain including legacy `codex_registry` dependency | FAIL / REMEDIATION REQUIRED |
| External authority matrix | applicable legal/tax/fiduciary/regulatory/banking/independent-assurance approvals | PENDING EXTERNAL |
| Pilot decision | technical controlled-pilot result | CONDITIONAL PASS / PRODUCTION NO-GO |

## Security-advisor boundary
The post-pilot security advisor reports no TST-schema findings. Remaining notices are inherited non-TST Geniza/WIM/PostGIS/public-schema findings and must be remediated under their respective programs before they are treated as ecosystem-wide production readiness.

## Decision
The TST controlled operational pilot is a **CONDITIONAL PASS** for the tested simulated control path. This is not production authorization. Production remains **NO-GO** until backup/restore is independently demonstrated, observability is operationalized, the parent migration replay defect is remediated, and applicable external authorities/professionals/providers approve the real-world operating model.
