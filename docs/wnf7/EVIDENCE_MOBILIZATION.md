# WNF-7 evidence mobilization

Status: system setup is complete for the 15-scenario technical package. The evidence is integrity-verified and registered as pending candidate evidence. Five reviewer roles are nominated, the Knowledge Governor role is staged pending independent board confirmation, and one alternate reviewer is registered in the controlled governance register. No reviewer has accepted, and human freshness review, substantive validation, adjudication, authority action, and production authorization have not occurred.

## Control outcome

The v1.3 exact-charter package supplies a complete automated portfolio: 15 of 15 scenarios produced valid advisory outputs, all 15 execution commands were null, the 15-entry ledger chain verified, and the automated defect register reported zero open defects. Seven artifact digests matched the package manifest; the manifest itself also has a separately recorded SHA-256 digest.

Those checks establish file and execution-record integrity only. They do not establish that an evidence packet is current, substantively sufficient, accepted by a reviewer, adjudicated, authoritative, or suitable for production.

| Control measure | Current | Required for authority review |
|---|---:|---:|
| Candidate scenario references mobilized | 15 | 15 |
| Candidate references with matched package integrity | 15 | 15 |
| Reviewer assignment slots initialized | 6 | 6 |
| Primary reviewer roles nominated | 5 | 6 |
| Primary reviewer roles awaiting independent confirmation | 1 | 0 |
| Accepted reviewer roles | 0 | 6 |
| Human-validated evidence packets | 0 | 15 |
| Completed human decisions | 0 | 15 |
| Release gate | HOLD | Separate accountable ruling |
| Production authorization | No | Not granted by this process |

The evidence-mobilization state is `MOBILIZED_PENDING_HUMAN_VALIDATION`. The authoritative operational readiness remains `HOLD_INCOMPLETE`.

The pre-approval setup state is `SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION`. The human designer is the proposed Knowledge Governor / Executive Sponsor, but that role remains unassigned until an independent board action confirms it. The design decision does not itself create approval authority.

## Controlled source model

- `SRC-011` identifies the controlled v1.3 exact-charter execution package.
- `SRC-013` identifies the controlled v1.5 human adjudication register.
- `SRC-014` identifies the controlled governance nomination register in the Drive Master Registry. It maps the approved human roster to opaque subject references; GitHub contains no personal email addresses.
- GitHub and Supabase store only controlled references and integrity metadata. Private Drive locations and document identifiers are intentionally excluded.
- Each scenario points to `controlled://SRC-011/scenario/SCN-nnn` and carries the SHA-256 of the charter-results artifact. The hash scope is explicitly the shared results artifact, not an independently hashed scenario file.

The machine-readable inventory is `pilot-evidence-mobilization-manifest.json`.

The strict portable contracts for the human stage are:

- `reviewer-appointment-submission.schema.json`;
- `evidence-validation-submission.schema.json`; and
- `adjudication-decision-submission.schema.json`.

## Scenario routing

| Scenario | Dimension | Automated posture | Accountable reviewer role | Required evidence |
|---|---|---|---|---|
| SCN-001 | Fear | PASS / eligible for human decision | SETC Control Owner | Authority and rule references |
| SCN-002 | Fear | BLOCKED / not eligible | SETC Control Owner | Negative resolver result and governing requirement |
| SCN-003 | Fear | BLOCKED / not eligible | SETC Control Owner | Authority metadata, expiry, scope, and denial trace |
| SCN-004 | Presence | REVIEW / simulation only | Technical Authority | Identity registry results and collision trace |
| SCN-005 | Knowledge | REVIEW / simulation only | QA Lead | Evidence timestamp and freshness policy |
| SCN-006 | Knowledge | REVIEW / simulation only | QA Lead | Both sources, contradiction record, and reviewer route |
| SCN-007 | Knowledge | BLOCKED / not eligible | QA Lead | Prompt/output trace and classification rule |
| SCN-008 | Wisdom | BLOCKED / not eligible | Pilot Product Owner | Purpose statement and architecture rule |
| SCN-009 | Understanding | REVIEW / simulation only | QA Lead | Jurisdiction inputs and unresolved lookup |
| SCN-010 | Understanding | BLOCKED / not eligible | QA Lead | Affected-party and risk analysis |
| SCN-011 | Counsel | BLOCKED / not eligible | Knowledge Governor | Approval matrix and missing approval trace |
| SCN-012 | Counsel | BLOCKED / not eligible | Knowledge Governor | Exception policy and lookup result |
| SCN-013 | Might / Power | BLOCKED / not eligible | SourceCube Technical Owner | Idempotency key and replay detection trace |
| SCN-014 | Might / Power | REVIEW / simulation only | SourceCube Technical Owner | Instruction trace and missing confirmation |
| SCN-015 | All seven | BLOCKED / not eligible | Knowledge Governor | Before/after records and mutation-isolation trace |

## Ecosystem coverage

SETC, SourceCube, Codex Veritas, SourceOne, SIOS, Sidekick OEL, SourceCoin, and SourceBlock remain covered by the shared WNF-7 profiles, 56 dimension bindings, eight adapters, and 24 allowlisted operations. The 15 exact-charter scenarios are a control portfolio for the pilot; they are not eight separate component certifications and do not authorize component execution.

## Database controls

The mobilization migration:

- adds one append-only pending candidate reference for each active pilot scenario;
- prevents duplicate scenario/reference pairs;
- records matched package integrity and a pending-human-review posture;
- exposes a service-role-only, security-invoker mobilization view; and
- leaves `wnf7.operational_readiness`, the release gate, and production authorization unchanged.

The human-control setup migration adds all six empty reviewer slots, a role-specific work queue, evidence lineage fields, and database triggers that reject validation or completed adjudication unless the designated reviewer has been accepted with no declared conflict. It also rejects role/scenario mismatches and requires validated evidence before a decision can be completed.

Evidence rows cannot be updated or deleted. A reviewer outcome must therefore be written as a new governed evidence record, preserving the original candidate and its provenance.

## Required human sequence

1. Independently confirm the Knowledge Governor designation, advance each nomination through assignment, and collect conflict declarations and explicit acceptance for all six required reviewer roles.
2. Review each controlled source, determine freshness, and write a new validation outcome without mutating the candidate record.
3. Complete one accountable decision for each of the 15 scenarios, including rationale and attestation where required.
4. Reconcile defects, contradictions, recusals, or remediation before readiness can be recalculated.
5. Submit any next non-production stage to the accountable authority. No derived state may self-advance the gate or authorize production.
