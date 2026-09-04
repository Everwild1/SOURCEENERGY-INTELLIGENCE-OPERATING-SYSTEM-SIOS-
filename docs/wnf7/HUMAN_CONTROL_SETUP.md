# WNF-7 human-control system setup

Status: pre-approval infrastructure complete. No reviewer is appointed or accepted, no evidence is human-validated, no adjudication is complete, Gate 3 remains `HOLD`, and production authorization remains false.

## Operating mode

The current operating mode is `SETUP`. The human designer is defining the system and its controls; that function is explicitly recorded as `SYSTEM_DESIGNER_NOT_APPROVER`. System design does not create reviewer standing, approval authority, or permission to execute.

## Initialized control surface

| Control object | Initialized state | Advancement requirement |
|---|---|---|
| QA Lead slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |
| Technical Authority slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |
| SETC Control Owner slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |
| SourceCube Technical Owner slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |
| Pilot Product Owner slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |
| Knowledge Governor / Executive Sponsor slot | UNASSIGNED | Named subject, appointment evidence, conflict disclosure, acceptance |

The six slots route all 15 pilot scenarios through `wnf7.reviewer_mobilization_queue`. The queue exposes assigned scenario count, outstanding evidence-validation count, and outstanding decision count for each role. It is service-role-only and uses invoker security.

## Appointment contract

A reviewer appointment packet must identify the reviewer and appointing subject independently, use controlled identity and appointment-evidence references, disclose conflict status, and include a timezone-aware effective date. A reviewer cannot appoint themself. `ACCEPTED` requires an explicit acceptance time and `NO_CONFLICT_DECLARED`; a conflict or recusal forces `HOLD`.

Parsing a valid packet does not update the database. A trusted administrative workflow must deliberately persist the governed state after checking the controlled appointment evidence.

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

## Adjudication contract

An adjudication packet records CONFIRM, OVERRIDE, or HOLD; an accountable rationale; the automated result reference; reviewed evidence references; and the decision time. A completed decision also requires a controlled attestation reference.

The database permits a `COMPLETE` decision only when the reviewer is accepted for the scenario's designated role and the same reviewer has produced a validated evidence record for that scenario. This is a completion gate, not execution authority.

## Readiness separation

`wnf7.human_control_setup_readiness` reports whether the pre-approval infrastructure is initialized. It cannot replace either `wnf7.evidence_mobilization_readiness` or `wnf7.operational_readiness`.

| State | Current value |
|---|---|
| Human-control setup | SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION |
| Evidence mobilization | MOBILIZED_PENDING_HUMAN_VALIDATION |
| Operational readiness | HOLD_INCOMPLETE |
| Release gate | HOLD |
| Production authorization | false |

The next phase begins only when named nominees and controlled appointment evidence are supplied. Until then, all reviewer roles remain unassigned and all approval counters remain zero.
