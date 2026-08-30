# SourceEnergy One API Contracts v1

Status: Draft / governed implementation contract

## SE1-01 Purpose Discovery

`POST /v1/sourceenergy-one/purpose-profiles`

Creates a protected, versioned Purpose Discovery profile. Raw narrative answers are testimony and must remain distinguishable from derived AI interpretation.

Required logical fields: `subjectId`, `version`, `responses`, `sourceUri`, `consentContext`.

State: `draft -> submitted -> superseded | withdrawn`.

## SE1-02 Codex 24 interpretation

`POST /v1/sourceenergy-one/purpose-profiles/{id}/codex24-interpretations`

Creates a candidate interpretation linked to the exact Purpose Profile version and evidence references.

Required logical fields: `purposeProfileId`, `version`, `interpretation`, `modelProvenance`, `evidenceRefs`.

State: `candidate -> reviewed | rejected | superseded`.

Codex 24 is registered as `EMERGING`. Interpretation is not an authoritative determination of identity, purpose, consciousness, destiny or future outcome.

## SE1-03 MVP + 100-Year Impact

`POST /v1/sourceenergy-one/impact-reports`

Creates a versioned draft containing Mission, Vision, Purpose, Impact Thesis and horizon statements for 1Y, 5Y, 10Y, 25Y, 50Y and 100Y.

State: `draft -> in_review -> approved | rejected | superseded`.

Long-horizon statements are impact intentions/scenarios, not predictions.

## SE1-04 Human approval

`POST /v1/sourceenergy-one/impact-reports/{id}/decisions`

Decision enum: `approve | reject | defer | request_revision`.

An approval must record actor identity/authority, decision time, consent receipt where applicable and artifact version. Only an approved report may be promoted to Genesis.

## SE1-05 SETC Genesis adapter

`POST /v1/sourceenergy-one/genesis-packages`

Preconditions:
1. Impact Report status is approved.
2. Approval decision is valid for the same artifact version.
3. Consent/policy checks pass.
4. Package hash and evidence references are generated.

Output: governed Genesis package with `setcGenesisRef` when SETC accepts the provenance record.

The adapter must not place raw sensitive questionnaire narratives into an immutable/public surface. It records approved claims, references, hashes, version and consent provenance.

## SE1-06 SourceCube orchestration

`POST /v1/sourceenergy-one/orchestration-plans`

Input: authenticated subject/organization context, approved Genesis context where available, user intent, permissions and relevant evidence.

Output: `plan`, `evidenceRefs`, `policyEvaluation`, `consequenceClass`, `authorizationStatus`, `correlationId`.

Consequence classes:
- `advisory`: information/recommendation; no execution authority.
- `operational`: bounded reversible workflow under delegated policy.
- `consequential`: financial, legal, governance, identity/permission, external commitment or similarly material action requiring the applicable authorization gate.

## Command safety

All mutating endpoints require idempotency keys. All calls carry correlation IDs. Authorization and execution events are append-only audit events. Client applications do not receive direct table access to the protected `sourceenergy_one` schema; access is through governed service APIs/RPCs.

## Authoritative data model

Supabase project: `SourceEnergy-command-backend`.
Protected schema: `sourceenergy_one`.
Tables: `purpose_profiles`, `codex24_interpretations`, `impact_reports`, `genesis_approvals`, `genesis_packages`, `orchestration_plans`, `audit_events`.
