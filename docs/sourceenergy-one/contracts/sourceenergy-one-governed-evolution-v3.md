# SourceEnergy One — Governed Evolution Contract v3

Status: Draft canonical implementation contract

## Canonical order of authority

Raw capture is permitted without interpretation. Advancement is governed by:

1. Evidence capture
2. Sevenfold Spirit Gate V3
3. Typed evidence provenance
4. SECI knowledge expansion
5. Codex24 / AI counsel with model provenance
6. Verified human confirmation under governed consent
7. 4P synthesis: Purpose, Product, People, Profit
8. Impact assessment
9. Human Genesis approval
10. Atomic append-only Genesis creation or supersession
11. SETC / SourceCube consumption under separate execution controls

## Sevenfold Spirit Gate V3

Canonical order:

Fear → Presence → Wisdom → Knowledge → Understanding → Counsel → Might

Canonical enterprise mapping:

- Fear: integrity / fiduciary boundary / compliance
- Presence: mission and values alignment
- Wisdom: architecture and strategic design
- Knowledge: evidence, intelligence and data governance
- Understanding: integration and systems coherence
- Counsel: decision rights, review and authorization
- Might: controlled execution, deployment and completion

Each dimension requires a substantive assessment, rationale and disposition. `human_confirmed` is possible only when every dimension is `aligned`. `hold` prevents advancement. Rejected assessments are retained and a later assessment may supersede them. `exempted` is not a passing state for operational advancement.

## Evidence provenance

Authoritative 4P evidence references are typed `evidence_provenance.id` UUIDs. Internal evidence must link to a satisfied Spirit Gate V3 assessment. External evidence enters through an Evidence Intake Envelope before Spirit Gate evaluation and typed admission.

## Identity and consent

Consequential confirmations require an active governed actor identity with at least `verified` assurance and an active governed consent receipt for the subject. Free-form actor and consent strings are historical metadata only and are insufficient for new consequential decisions.

## AI provenance

AI output remains counsel. Governed inference records bind provider, model/version, system-policy version, prompt-template hash, tool-policy hash, typed input evidence, aggregate input hash, output hash, subject and consent. Knowledge insights and Purpose/4P reflections cannot become human-confirmed without an inference record backed by active model provenance.

## 4P and Genesis

Every Purpose, Product, People and Profit dimension requires typed evidence. Genesis is immutable. Material evolution uses an append-only chain:

G1 → lived experience / evidence → Spirit Gate → SECI / Codex24 → human confirmation → 4P evolution nomination → new Impact → new approval → atomic supersession → G2.

The superseding package must exactly equal the approved nominated 4P profile and contain `prior_genesis_id = G1`. A prior Genesis may have only one authoritative successor.

## AuditLedger

`audit_events` is append-only. Events are hash chained and mutation is prohibited. `verify_audit_chain()` must report no invalid links before a production release is promoted.

## Reflection confirmation invariant

No Purpose reflection may be inserted already confirmed. `promote_confirmed_knowledge_to_reflection` creates `pending` only. Final confirmation must traverse typed evidence, Spirit Gate V3, verified identity, governed consent and AI provenance.

## Boundary rules

- Raw journal narrative does not automatically enter Genesis, SETC or SourceCube.
- AI cannot approve its own counsel.
- Spirit Gate does not replace applicable law, regulatory authority, evidentiary verification or human governance.
- Profit analysis does not authorize transactions, promise returns or move capital.
- Journal, SECI or Genesis state cannot directly execute consequential actions.
- Corrections and evolution supersede earlier states while retaining provenance.
