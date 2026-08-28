# Workforce Ecology Index (WEI) 1.0 — Governance and SIOS Read Models

Status: **Approved for limited pilot — activation pending accountable reviewer and identity assignments**

## Purpose

WEI is a governed decision-support instrument for measuring organizational workforce conditions across seven dimensions without diagnosing individuals or creating autonomous personnel decisions.

## Dimensions and weights

- Productive Performance — 20%
- Human Connection — 15%
- Social Capital — 15%
- Development — 15%
- Belonging — 10%
- Sustainable Capacity — 15%
- Community Contribution — 10%

## Governance controls

- Any dimension below 40 creates `DIMENSION_THRESHOLD_BREACH` and prevents a healthy aggregate score from masking a critical deficiency.
- Two or more critical human dimensions below 40 across Human Connection, Belonging, and Sustainable Capacity create `MANDATORY_EXECUTIVE_REVIEW`.
- Productive Performance above 85 with Sustainable Capacity below 50 creates `UNSUSTAINABLE_PERFORMANCE` and caps an otherwise Flourishing or Resilient classification at Watch.
- Governance flags are advisory controls and do not autonomously determine employment status, workplace location, or personnel action.
- WEI-1.0 baseline calculation requires all seven dimensions, 100% approved-metric evidence completeness, and at least two evidence classes per dimension.
- Current minimum cohort-size policy is 5. Cohort-size enforcement must not be claimed until observation-level cohort support is implemented.

## Canonical Supabase boundary

Project: `SourceEnergy-command-backend`

Private schema: `workforce_ecology`

Canonical tables include `metric_registry`, `measurement_observations`, `dimension_scores`, `index_scores`, `interventions`, `policy_versions`, `audit_events`, `production_gate`, `governance_reviewers`, `pilot_authorizations`, and `pilot_identity_mappings`.

Canonical tables remain private. RLS is enabled and ordinary `anon` / `authenticated` access is not granted under the current server-only architecture.

## SIOS read models

Private `security_invoker` read models include:

- `workforce_ecology.sios_wei_current`
- `workforce_ecology.sios_wei_dimension_scorecard`
- `workforce_ecology.sios_wei_intervention_queue`
- `workforce_ecology.sios_wei_governance_panel`
- `workforce_ecology.sios_wei_production_gate`
- `workforce_ecology.sios_wei_pilot_readiness`

These views are not granted to `anon` or `authenticated`; `service_role` has governed server-side SELECT access.

## Controlled pilot authorization

Migration `workforce_ecology_controlled_pilot_authorization_v1` advanced `WEI-1.0` from draft to **approved**, with `approval_scope = limited_pilot` and authorization reference `WEI-1.0-LIMITED-PILOT-2026-08-28`.

This is not unrestricted-production authorization.

Current state:

- Policy status: **approved**
- Approval scope: **limited_pilot**
- Pilot authorization: **approved_pending_assignments**
- Pilot readiness: **false**
- Production gate: **blocked**
- Required reviewer roles: **5**
- Assigned reviewer roles: **0**
- Verified identity mappings: **0**

## Required accountable roles

The pilot requires five named human-accountability assignments before activation:

1. Executive Sponsor
2. Workforce Governance Reviewer
3. Privacy & Human Review
4. Technical Data Steward
5. Pilot Operating Unit Owner

The registry deliberately leaves these roles unassigned until real accountable principals are designated. The system does not invent or infer governance personnel.

## Data-ingestion boundary

No real workforce data is authorized for pilot calculation until required reviewer assignments are active and a pilot identity mapping has been verified. Clinical diagnoses, therapy records, medication information, and individual psychological-risk scoring remain excluded.

## Production gate

`WEI-1.0-PRODUCTION-GATE` remains **blocked**. No production authorization reference, production authorized-by reference, or production authorization timestamp has been recorded.

The limited-pilot approval cannot be interpreted as controlled-scale or unrestricted-production approval.

## Validation and security state

Governance hardening has been validated with transaction-isolated synthetic scenarios, including normal operation, a critical Human Connection dimension, unsustainable high performance / low capacity, and multiple critical human dimensions. Synthetic validation data was rolled back rather than retained.

The SIOS workforce read models contain no production workforce scores because no real workforce evidence has been introduced.

Post-migration security review continues to report the private `workforce_ecology` tables as RLS-enabled with no end-user policies. Broader pre-existing backend findings are outside this WEI authorization and were not changed by this migration.

## Institutional sequence

**Assign Accountable Reviewers → Verify Pilot Organization / Operating-Unit Identity → Activate Limited Pilot → Introduce Approved Non-Clinical Evidence → Run Pilot WEI → Fairness / Privacy / Signal Review → Institutional Acceptance Decision → Controlled Scale**

## Control principle

> Aggregate strength cannot conceal critical human-system weakness.

WEI provides evidence for accountable human governance; it is not an autonomous workforce authority.
