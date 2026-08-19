# SC-E11 — Controlled Source Coin Testnet

## Authority boundary
SC-E11 validates operations; it does not activate Source Coin production economics. SC-E12 remains the independent production authorization gate.

The testnet must use a separate Supabase project/environment. Production keys, service-role secrets, wallets and sensitive participant data are prohibited. All institutions and balances are synthetic.

## Required scenario matrix
1. Transfer conservation and insufficient-funds rejection.
2. Settlement finality, expiry and duplicate/replay rejection.
3. Validated contribution reward from an authorized funding account; no reward minting.
4. Treasury authorization and separation of duties.
5. Compliance/policy DENY and fail-closed behavior.
6. Replay/idempotency attack simulation.
7. Concurrent/race execution against the same economic intent.
8. Supabase/outbox outage and deterministic recovery.
9. Emergency pause, blocked execution and governed release.
10. Test credential/key rotation exercise.
11. Migration forward/rollback rehearsal using synthetic state.
12. Ledger-to-projection/accounting reconciliation.

## Evidence package
Each scenario must emit a stable evidence reference, correlated execution identifiers, invariant references and a pass/fail result. The SC-E11 evidence manifest is an input to SC-E12 and is not itself an authorization artifact.

## Operational runbook
- Confirm the environment contains no production material.
- Initialize deterministic synthetic genesis allocation.
- Run the complete scenario matrix.
- Exercise emergency pause and recovery.
- Exercise credential rotation and migration recovery.
- Reconcile authoritative ledger state to projections/accounting outputs.
- Record all defects and classify severity.
- Repeat failed scenarios after remediation; preserve prior evidence.

## Exit criteria
SC-E11 is exit-ready only when every required scenario passes, reconciliation passes, runbooks have been exercised, and there are zero unresolved critical findings. High findings require explicit SC-E12 disposition before any production consideration.

Passing SC-E11 grants no mint, burn, treasury, custody or production-economy authority.
