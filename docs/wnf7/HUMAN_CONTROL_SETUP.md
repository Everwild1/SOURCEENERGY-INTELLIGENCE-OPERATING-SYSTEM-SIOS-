# WNF-7 human-control system setup

Status: pre-approval infrastructure complete. Five primary reviewers are nominated, the Knowledge Governor / Executive Sponsor designation is staged for independent board confirmation, and one alternate reviewer is recorded in controlled register `SRC-014`. No reviewer is assigned or accepted, no evidence is human-validated, no adjudication is complete, Gate 3 remains `HOLD`, and production authorization remains false.

## Operating mode

The current operating mode is `SETUP`. The human designer is defining the system and its controls; that function is explicitly recorded as `SYSTEM_DESIGNER_NOT_APPROVER`. System design does not create reviewer standing, approval authority, or permission to execute.

## Initialized control surface

| Control object | Initialized state | Advancement requirement |
|---|---|---|
| QA Lead slot | NOMINATED | Conflict disclosure, assignment, acceptance |
| Technical Authority slot | NOMINATED | Conflict disclosure, assignment, acceptance |
| SETC Control Owner slot | NOMINATED | Conflict disclosure, assignment, acceptance |
| SourceCube Technical Owner slot | NOMINATED | Conflict disclosure, assignment, acceptance |
| Pilot Product Owner slot | NOMINATED | Conflict disclosure, assignment, acceptance |
| Knowledge Governor / Executive Sponsor slot | UNASSIGNED / DESIGNATION STAGED | Independent board confirmation, conflict disclosure, assignment, acceptance |

The six slots route all 15 pilot scenarios through `wnf7.reviewer_mobilization_queue`. The queue exposes assigned scenario count, outstanding evidence-validation count, and outstanding decision count for each role. It is service-role-only and uses invoker security. The alternate reviewer remains outside the six primary slots until a controlled replacement is required.

## Appointment contract

A reviewer appointment packet must identify the reviewer and appointing subject independently, use controlled identity and appointment-evidence references, disclose conflict status, and include a timezone-aware effective date. A reviewer cannot appoint themself. `ACCEPTED` requires an explicit acceptance time and `NO_CONFLICT_DECLARED`; a conflict or recusal forces `HOLD`.

Parsing a valid packet does not update the database. A trusted administrative workflow must deliberately persist the governed state after checking the controlled appointment evidence.

The server-side `WNF7HumanControlService` now provides that persistence boundary. It permits only the controlled lifecycle `UNASSIGNED -> NOMINATED -> ASSIGNED -> ACCEPTED`, with `HOLD` available for conflict or remediation. Direct acceptance is rejected, and replacing a named subject requires the slot to enter `HOLD` first. Each write includes the previously read assignment UUID and lifecycle status so a concurrent change fails closed. The service never exposes a release, authorization, execution, deletion, or production method.

## Evidence-validation contract

Human review never updates or deletes the original candidate record. It writes a new append-only evidence record linked to the candidate by UUID and controlled reference. A validation outcome requires:

- the reviewer role assigned to that scenario;
- an accepted reviewer assignment for the same reviewer subject;
- a no-conflict declaration and appointment evidence;
- a new controlled validation reference and SHA-256 digest;
- observation and validation times;
- a freshness ruling and rationale; and
- `CURRENT` or `NOT_APPLICABLE` freshness before the outcome may be `VALIDATED`.

The database trigger rejects validation from unassigned, nominated, assigned-but-unaccepted, conflicted, recused, or wrong-role reviewers.

Before append, the trusted service independently checks the active scenario-role mapping, accepted reviewer identity, appointment evidence, and exact pending candidate record. The database trigger remains the final enforcement layer.

## Adjudication contract

An adjudication packet records CONFIRM, OVERRIDE, or HOLD; an accountable rationale; the automated result reference; reviewed evidence references; and the decision time. A completed decision also requires a controlled attestation reference.

The database permits a `COMPLETE` decision only when the reviewer is accepted for the scenario's designated role and the same reviewer has produced a validated evidence record for that scenario. This is a completion gate, not execution authority.

The trusted service also resolves the governed automated-result candidate and every cited validated-evidence reference before appending a decision. Each persistence result is wrapped in a receipt with `may_execute = false`, `production_authorized = false`, and `authority_posture = DOES_NOT_CONFER_AUTHORITY`.

## Readiness separation

`wnf7.human_control_setup_readiness` reports whether the pre-approval infrastructure is initialized. It cannot replace either `wnf7.evidence_mobilization_readiness` or `wnf7.operational_readiness`.

| State | Current value |
|---|---|
| Human-control setup | SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION |
| Evidence mobilization | MOBILIZED_PENDING_HUMAN_VALIDATION |
| Operational readiness | HOLD_INCOMPLETE |
| Release gate | HOLD |
| Production authorization | false |

The next phase requires independent confirmation of the Knowledge Governor designation plus conflict declarations, assignment, and acceptance for every primary nominee. Nomination alone cannot validate evidence or complete adjudication; all approval counters remain zero.
