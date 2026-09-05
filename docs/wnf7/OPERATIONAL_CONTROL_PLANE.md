# WNF-7 operational control plane

Status: shared runtime, component-adapter, and persistence implementation on a feature branch for controlled validation. Production authorization remains false.

## Purpose

WNF-7 makes the seven dimensions an executable governance and meaning framework across SETC, SourceCube, Codex Veritas, SourceOne, SIOS, Sidekick OEL, SourceCoin, SourceBlock, and future approved SourceEnergy components. It records classifications, evidence, accountable adjudications, and release posture without asserting spiritual, legal, financial, regulatory, custody, or settlement authority.

WNF-7 is a shared control-plane layer, not a ninth product silo. Each component keeps its authoritative domain and connects through a versioned profile and seven component-specific control bindings.

## System boundaries

| System | Authoritative responsibility |
|---|---|
| Google Drive | Approved doctrine, profiles, human-readable review register, and evidence references |
| GitHub | Versioned schemas, migrations, tests, CI gates, and release history |
| Supabase | Dimension registry, component mappings, scenarios, reviewer assignments, evidence metadata, adjudications, and release state |
| SETC | Authority resolution, governance evaluation, review routing, and fail-closed control |
| SourceCube | Context classification, evidence lineage, reproducible advisory analysis, and null-command enforcement |
| SourceCoin | Eligibility and governance signals only; no minting, transfer, custody, valuation, redemption, or settlement authority |

## Runtime flow

1. A component submits one of its three allowlisted assessment operations through `WNF7ComponentGateway`.
2. The registered adapter fixes the component, profile, adapter version, operation, and consequence class. Callers cannot downgrade impact classification.
3. The adapter rejects executable commands, requested external side effects, reserved adapter metadata, and secret-bearing metadata.
4. The adapter supplies one evidence-backed observation for each of the seven dimensions.
5. `setc.wnf7` verifies the component/profile/adapter/operation binding and orders all seven observations canonically.
6. The evaluator applies fail-closed aggregation. Any BLOCKED dimension blocks the assessment; any Fear result other than PASS also blocks it.
7. A REVIEW or approved NOT_APPLICABLE result limits the assessment to simulation and human review.
8. An all-PASS result is only `ELIGIBLE_FOR_HUMAN_DECISION`; it is not approval and never contains an execution command.
9. The trusted server adapter writes the result once to `wnf7.assessment_records`. Component plus idempotency key is unique, and updates or deletes are rejected.
10. SETC and the accountable reviewers may use the immutable record as input to the existing evidence, adjudication, and release-gate process.

External component payloads enter through `WNF7ComponentIngress`. The server supplies an authenticated component identity separately from the submitted payload; a mismatch is rejected before evaluation or persistence. The strict ingress accepts only the fields defined by `component-assessment-submission.schema.json`. Callers cannot provide or override the governed profile, adapter identity, adapter version, consequence class, execution command, side-effect request, or production posture.

The runtime package includes 56 distinct component/dimension bindings. Each binding identifies the operating focus, canonical control reference, and accountable reviewer role for that component under that dimension.

## Component adapter contract

The code and database share eight versioned adapter identities and 24 allowlisted operations. Every adapter is `PILOT`, `production_authorized = false`, and `external_side_effects = false`.

| Component | Adapter operations | Fixed posture |
|---|---|---|
| SETC | `AUTHORITY_REVIEW`, `POLICY_DECISION`, `RELEASE_GATE_REVIEW` | Operational or consequential review; never self-approval |
| SourceCube | `CONTEXT_CLASSIFICATION`, `EVIDENCE_SYNTHESIS`, `ADVISORY_PLAN` | Informational/advisory only |
| Codex Veritas | `CLAIM_ASSESSMENT`, `CONTRADICTION_REVIEW`, `PUBLICATION_REVIEW` | Evidence and publication review only |
| SourceOne | `HUMAN_ACTION_REVIEW`, `APPROVAL_CONTEXT`, `OUTCOME_EXPLANATION` | Presents context; cannot turn interface action into authority |
| SIOS | `WORKFLOW_TRANSITION_REVIEW`, `CROSS_DOMAIN_HANDOFF`, `RELEASE_READINESS` | Reviews state and handoff; cannot execute or confirm external effects |
| Sidekick OEL | `WORK_ITEM_INTAKE`, `DELEGATION_REVIEW`, `OUTCOME_REVIEW` | Remains bounded by delegated OEL/SETC authority |
| SourceCoin | `ECONOMIC_ELIGIBILITY`, `TRANSFER_ELIGIBILITY`, `SETTLEMENT_ELIGIBILITY` | Eligibility only; no economic mutation or finality |
| SourceBlock | `LIFECYCLE_GATE`, `VALUE_EVIDENCE_REVIEW`, `CLOSURE_REVIEW` | Lifecycle review only; no manufactured value, ownership, or finality |

`WNF7ComponentGateway` is the single application entry point. `component_adapter(...)` also exposes the individual component port when a domain service needs an explicit dependency. Both paths return an assessment receipt whose `may_execute` property is always false.

`WNF7ComponentIngress` is the portable application boundary for authenticated component traffic. It validates exact fields, timezone-aware timestamps, canonical dimension and status values, one observation for every dimension, safe metadata, and authenticated-component equality before routing to the gateway. Authentication itself remains the responsibility of the trusted server transport; no direct browser or anonymous Supabase access is enabled by this interface.

## Component responsibilities

| Component | WNF-7 operating mandate | Hard boundary |
|---|---|---|
| SETC | Authority resolution, governance evaluation, review routing, and fail-closed control | Cannot manufacture external authority |
| SourceCube | Context classification, evidence lineage, reproducible advisory analysis, and null-command enforcement | Cannot authorize transactions or mutate authoritative systems |
| Codex Veritas | Provenance, claim state, confidence, contradiction history, supersession, and truth/meaning separation | Interpretation cannot substitute for evidence or authority |
| SourceOne | Human-facing explanations, warnings, approvals, and outcome visibility | Cannot hide or bypass blocked gates |
| SIOS | APIs, events, state machines, observability, enforcement, and confirmation | Cannot treat unconfirmed external effects as complete |
| Sidekick OEL | Accountable work, delegated commands, evidence, escalation, and outcome review | Cannot exceed delegated authority or SETC approval |
| SourceCoin | Governed economic interoperability after authorized instruction | No automatic minting, transfer, custody, valuation, redemption, or settlement |
| SourceBlock | Bounded project, activity, or value-producing unit carrying 7D from initiation through closure | A record or anchor cannot manufacture ownership, value, authority, completion, or external finality |

Every profile maps to all seven dimensions, producing 56 required component-dimension controls.

## Assessment persistence contract

`wnf7.assessment_records` is private, RLS-enabled, and available only to trusted server-side `service_role` access. It stores references and bounded findings rather than credentials, private keys, full payment messages, or unnecessary personal data.

Each row requires:

- a canonical component/profile pair;
- a canonical adapter, adapter version, and allowlisted operation whose fixed consequence class cannot be downgraded;
- all seven dimension results exactly once;
- at least one evidence reference and one control reference per dimension;
- a timezone-aware observation time, correlation ID, and component-scoped idempotency key;
- deterministic SHA-256 input and output hashes;
- `human_review_required = true`; and
- `execution_command = null`.

The caller-facing submission schema intentionally excludes `profile_code`, `adapter_code`, `adapter_version`, `consequence_class`, `execution_command`, external-side-effect flags, and production authorization. These fields are derived or prohibited at the trusted application boundary.

Automated state and decision eligibility are generated from the seven stored results by immutable database functions. This creates an independent database check on the Python evaluator's result.

## Seven-dimensional contract

| Dimension | Operational question |
|---|---|
| Fear of the Lord | Is governing authority legitimate, current, in scope, and sufficient? |
| Presence of the Lord | Are identity, provenance, time, place, and version contextually intact? |
| Wisdom | Is the action aligned to purpose, stewardship, and durable value? |
| Knowledge | Is evidence attributable, current, classified, and contradiction-aware? |
| Understanding | Are jurisdiction, affected parties, uncertainty, and consequences understood? |
| Counsel | Have required reviewers, approvals, exceptions, and dissent pathways been engaged? |
| Might / Power | Is capability bounded by authorization, confirmation, idempotency, reversibility, and audit evidence? |

## Release law

- Automated evaluation may return PASS, REVIEW, or BLOCKED.
- Derived readiness may reach READY_FOR_AUTHORITY_REVIEW but never advances a release gate automatically.
- Production authorization requires an explicit AUTHORIZED gate state and an accountable authority attestation reference.
- Evidence and adjudication records are append-only; corrections require superseding governed records.
- Client roles receive no direct access to the private wnf7 schema.
- Production remains on HOLD until six reviewer roles are accepted, 15 evidence packets are validated, 15 decisions are complete, and accountable authority acts.

## Evidence mobilization

The integrity-verified v1.3 exact-charter package is represented by 15 append-only candidate evidence references, one for each pilot scenario. All references begin in `PENDING` freshness and validation states. Package hash verification proves artifact integrity, not substantive sufficiency or human acceptance.

`wnf7.evidence_mobilization_readiness` separates logistical mobilization from operational readiness. With all 15 candidate references present and their package integrity matched, it reports `MOBILIZED_PENDING_HUMAN_VALIDATION`; `wnf7.operational_readiness` remains `HOLD_INCOMPLETE` until all six reviewers are accepted, 15 evidence packets are human-validated, and 15 decisions are complete. Neither view advances the release gate or authorizes production.

The governed inventory and reviewer routing are documented in `pilot-evidence-mobilization-manifest.json` and `EVIDENCE_MOBILIZATION.md`. They use controlled references `SRC-011` and `SRC-013` and intentionally exclude private Drive locations.

## Human-control setup

The pre-approval system initializes six unassigned reviewer slots and strict portable contracts for reviewer appointment, evidence validation, and adjudication. The human designer remains separate from approval authority. No role is accepted until a named reviewer, an independent appointing subject, controlled appointment evidence, a conflict declaration, and explicit acceptance are present.

Database triggers require the scenario's designated accepted reviewer before evidence can be validated, preserve candidate evidence through linked append-only validation records, and require both validated evidence and an accepted reviewer before adjudication can be completed. `wnf7.human_control_setup_readiness` may report `SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION`; this is a setup status only and cannot advance operational readiness, Gate 3, or production.

The detailed contract is documented in `HUMAN_CONTROL_SETUP.md`.

## Controlled references

- PILOT-7D-001
- SETC-PROFILE-7D-001
- SETC-7D-IMPLEMENTATION-001
- SRC-013 — Human Adjudication Control Register v1.5
- SRC-011 — Exact Charter Execution package v1.3

## Validation

Apply the migrations in an isolated Postgres 17 or Supabase development branch, then execute the three `supabase/tests/wnf7_*.sql` contracts. Run `python -m unittest discover -s tests -p 'test_wnf7_*.py' -v` for the shared runtime, manifest, and human-control checks. CI verifies eight adapters, 24 operations, all 56 dimension bindings, strict authenticated ingress, cross-component spoofing prevention, component/profile/adapter integrity, consequence anti-downgrade enforcement, deterministic aggregation, idempotency, private client access, RLS, null-command enforcement, append-only assessments/evidence/decisions, the candidate evidence inventory, six unassigned reviewer slots, role-bound validation and adjudication, and the continuing HOLD posture.
