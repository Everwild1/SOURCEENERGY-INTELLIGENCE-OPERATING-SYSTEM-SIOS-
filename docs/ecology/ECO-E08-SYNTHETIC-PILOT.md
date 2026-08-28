# ECO-E08 — Synthetic Closed-Loop Ecology Pilot

## Purpose
ECO-E08 is the integration proof for the Ecology Block. It exercises E01–E07 as one deterministic synthetic regenerative cycle without production endpoints, secrets, real assets, real money, ledger mutation, or settlement finality.

## Canonical trace
Authority/Evidence → Research/Creation → IP/Rights → Commercialization → Venture/Enterprise → Market Opportunity → Capital Readiness → Capital → Transaction → Settlement Reference → Impact → Regenerative Allocation → Reinvestment → next Research cycle.

The final transition is the architectural proof that commercialization is not terminal: measured value can inform a governed reinvestment proposal that returns capacity to the ecology.

## Evidence posture
Every pilot stage emits deterministic synthetic evidence keyed by pilot ID and stage. The harness returns a `PilotReport` containing stage results, injected-failure evidence, closed-loop status and an explicit `production_effects=False` assertion.

## Failure injection
The harness proves fail-closed behavior for replayed material gateway requests, missing idempotency, unauthorized target actions and allocation authority concentration. It also asserts that Source Coin settlement finality is not created and that Ecology/gateway artifacts cannot escalate authority.

## Source Coin boundary
Source Coin is exercised only as a mocked request/reference target. The pilot does not invoke a Source Coin production endpoint, mutate a wallet or ledger, create an economic effect, or bypass release governance.

## Production readiness interpretation
A passing E08 proves contract integration and closed-loop semantics. It does **not** constitute production certification. ECO-E09 must separately evaluate security, operational controls, authoritative adapters, Supabase persistence hardening, Source Coin release posture, external settlement/legal authority, observability, recovery, and governance authorization.
