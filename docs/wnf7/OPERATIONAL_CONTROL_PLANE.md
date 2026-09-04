# WNF-7 operational control plane

Status: implemented on a feature branch for controlled validation. Production authorization remains false.

## Purpose

WNF-7 makes the seven dimensions an executable governance and meaning framework across SETC, SourceCube, SourceCoin, and future SourceEnergy components. It records classifications, evidence, accountable adjudications, and release posture without asserting spiritual, legal, financial, regulatory, custody, or settlement authority.

## System boundaries

| System | Authoritative responsibility |
|---|---|
| Google Drive | Approved doctrine, profiles, human-readable review register, and evidence references |
| GitHub | Versioned schemas, migrations, tests, CI gates, and release history |
| Supabase | Dimension registry, component mappings, scenarios, reviewer assignments, evidence metadata, adjudications, and release state |
| SETC | Authority resolution, governance evaluation, review routing, and fail-closed control |
| SourceCube | Context classification, evidence lineage, reproducible advisory analysis, and null-command enforcement |
| SourceCoin | Eligibility and governance signals only; no minting, transfer, custody, valuation, redemption, or settlement authority |

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

## Controlled references

- PILOT-7D-001
- SETC-PROFILE-7D-001
- SETC-7D-IMPLEMENTATION-001
- SRC-013 — Human Adjudication Control Register v1.5

## Validation

Apply the migration in an isolated Postgres 17 or Supabase development branch, then execute supabase/tests/wnf7_operational_control_plane.sql. CI verifies registry counts, ecosystem boundaries, RLS, private client access, append-only evidence and decisions, and the initial HOLD posture.
