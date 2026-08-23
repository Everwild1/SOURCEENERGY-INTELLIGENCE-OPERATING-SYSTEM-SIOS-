# TST Controlled Pilot Execution Package

## Classification
PILOT ONLY / NON-PRODUCTION. This package does not authorize real-world transfers, fiduciary activity, regulated activity, tax treatment, or production banking/payment rails.

## Objective
Generate reproducible evidence that the complete TST governance chain can be operated under segregation of duties and exception controls before any production GO decision.

## Pilot roles
Assign distinct named participants before execution:
- Pilot System Owner
- Trustee Approver
- Treasury Executor
- Independent Reconciler
- Compliance Validator
- Security/Operations Owner

No participant may combine roles where the TST database contract prohibits the combination for the same transaction.

## Pilot transaction chain
1. Create/verify stewardship entity.
2. Activate tithe election and calculation.
3. Record simulated or nominal authorized contribution.
4. Place value in restricted stewardship fund.
5. Establish authorized allocation.
6. Verify beneficiary eligibility/compliance/conflict state.
7. Create distribution request.
8. Prove initiator self-approval is denied.
9. Record independent trustee approval.
10. Release to treasury.
11. Prove final approver cannot execute payment.
12. Execute only against a test/sandbox or expressly authorized nominal-value destination.
13. Prove duplicate payment is rejected.
14. Record settlement.
15. Prove executor cannot reconcile.
16. Complete independent reconciliation.
17. Exercise one reconciliation mismatch and confirm HOLD behavior.
18. Capture evidence records and integrity hashes.
19. Verify append-only audit chain.
20. Generate final stewardship statement and trustee attestation.
21. Assemble assurance package.
22. Exercise a HIGH control finding and verify readiness is blocked.
23. Attach remediation evidence, validate independently and close finding.
24. Verify compliance readiness.

## Evidence manifest
Capture for every pilot run: environment identifier; git commit SHA; migration/test run IDs; transaction correlation ID; participant/role IDs; timestamps; contribution/allocation/distribution/payment/reconciliation IDs; negative-control results; evidence SHA-256 values; audit-chain verification result; statement hash; trustee attestation; assurance package ID; findings/remediation IDs; backup/restore evidence; observability evidence; and final decision record.

Do not commit account numbers, credentials, personal beneficiary data, private keys, tokens, or unmasked banking details to GitHub.

## Backup/restore gate
Before production consideration, demonstrate in a non-production environment: logical database backup; successful restore to an isolated database; row/count/control reconciliation after restore; audit-chain verification after restore; evidence locator recovery; secret/key recovery procedure without exposing secret values; and documented RTO/RPO observations.

## Observability gate
Operational monitoring must cover: migration failure; privileged authorization failure; repeated denied approval attempts; distribution/payment exceptions; duplicate-payment rejection; settlement/reconciliation mismatch; HOLD state; audit-chain verification failure; overdue HIGH/CRITICAL finding; overdue compliance obligation; assurance issuance failure; backup failure.

Each alert must have a named owner, severity, escalation route and response objective before production GO.

## Pilot acceptance criteria
PASS requires: full regression green on the pilot commit; all positive-path stages complete; all mandatory negative controls reject correctly; reconciliation HOLD works; audit chain verifies; assurance package completes; compliance blocker and remediation cycle work; backup/restore passes; observability evidence exists; no secrets/PII leaked; and accountable approvers sign the pilot decision.

Any failed, missing or unverified criterion = PILOT NOT ACCEPTED.

## Production GO boundary
A successful controlled pilot establishes operational evidence only. Production remains NO-GO until applicable external legal, tax, fiduciary, regulatory, banking/payment-provider and independent assurance requirements have been documented and approved by the responsible real-world authorities/professionals.
