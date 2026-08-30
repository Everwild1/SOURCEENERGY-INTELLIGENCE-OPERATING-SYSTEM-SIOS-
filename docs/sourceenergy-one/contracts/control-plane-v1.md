# SourceEnergy One Control Plane v1

## SE1-07 Experience/API Gateway

SourceEnergy One exposes a single governed experience boundary. UI, voice and future device clients submit authenticated intents; they do not call protected SourceEnergy One tables directly.

Gateway responsibilities: authentication context, idempotency, correlation ID, request validation, rate/abuse controls, consent context and routing to bounded services.

## SE1-08 Identity + Policy Enforcement

Every protected request resolves an Access Context containing subject, actor, organization context, roles, permissions, assurance level and expiry.

Before orchestration or execution the policy layer records `allow`, `deny`, or `require_authorization` with applicable policy references and reasons. A SourceCube recommendation cannot override a deny or authorization requirement.

## SE1-09 SIOS Domain Adapters

All SIOS connectivity is allowlisted in `sourceenergy_one.domain_adapter_registry`.

Initial registry:
- `setc-organizations`: enabled read adapter to authoritative SETC organization context.
- `setc-genesis`: disabled write/proposal path until the explicit Genesis promotion gate is implemented and tested.
- `sourcecube`: disabled consequential handoff until authorization and receipt controls are implemented and tested.

Adapters declare authority, mode, consequence ceiling, contract version and enabled state. No arbitrary database-table routing is permitted.

## SE1-10 Audit + Observability

Every cross-service operation carries a correlation ID. Policy decisions, orchestration plans and execution receipts are traceable by that ID. External execution must produce a receipt recording adapter, external reference, status and evidence payload.

The audit model preserves the distinction between observation, inference, recommendation, authorization and execution.

## SE1-11 QA + Controlled Release

Release gates:
1. Contract/schema validation.
2. RLS and privilege tests prove protected tables are inaccessible to anon/authenticated clients.
3. Codex 24 outputs remain candidate interpretations until human approval.
4. Genesis promotion fails closed without matching approved artifact + approval + consent/policy evidence.
5. Consequential SourceCube adapters remain disabled until authorization tests pass.
6. Idempotency/replay tests prevent duplicate consequential mutations.
7. Correlation/audit tests prove end-to-end provenance.
8. Threat-model and privacy review for Purpose Discovery narrative data.
9. Staging smoke test across Purpose Discovery -> Codex 24 -> MVP/Impact -> approval -> Genesis proposal -> SourceCube advisory plan.
10. Production promotion requires accountable human approval.

## Backend objects

Protected schema additions: `access_contexts`, `policy_decisions`, `domain_adapter_registry`, `execution_receipts`.

These extend the SE1-01 through SE1-06 foundation without granting direct client access.
