# ECO-E06 — Regenerative Allocation / Reinvestment Model

## Purpose
ECO-E06 converts ECO-E05 Wealth Ecology intelligence into governed, explainable allocation proposals. A proposal is a coordination artifact, never a payment, settlement, treasury, ledger, fiduciary, compliance, ownership, or investment-approval instruction.

## Flow
ECO-E04 governed projections → ECO-E05 intelligence → ECO-E06 candidate eligibility and weighting → proposal → external review/authorization reference → ECO-E07 integration request boundary.

## Deterministic policy
Candidates require ECO-E05 intelligence references and a confidence posture. Eligibility fails closed below the configured minimum confidence. Weight is `score × confidence`. Candidate, target-category, and source-authority concentration caps constrain proposals. Authority concentration violations fail closed rather than being silently redistributed.

Unallocated capacity is allowed. ECO-E06 does not force 100% deployment merely because funds or value capacity are referenced as available.

## Proposal lifecycle
`draft → proposed → reviewed → externally_authorized | rejected | superseded`

`externally_authorized` requires a reference to the actual external authority. Ecology cannot issue that authority to itself. `superseded` requires lineage to the proposal it corrects/replaces.

## Authority invariants
- Proposal ≠ payment instruction.
- Proposal ≠ settlement finality.
- Proposal ≠ Source Coin ledger or balance mutation.
- Proposal ≠ Capitalization treasury authorization.
- Proposal ≠ WIM transaction creation/finality.
- Proposal ≠ HEI fiduciary or IP ownership action.
- Intelligence score ≠ compliance or investment approval.
- External authorization remains reference-only inside Ecology.

## ECO-E07 handoff
ECO-E07 may expose an authenticated request/integration gateway that transports a reviewed proposal to the relevant authoritative domain. The gateway must preserve correlation, causation, idempotency, source references and external authorization evidence. It must not reinterpret an Ecology proposal as final execution authority.

## Persistence posture
No new production DDL is introduced by this contract gate. The existing ECO-E04 `ecology.regenerative_projections` projection table can be evolved only after this model and CI gate are accepted.