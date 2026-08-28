# Workforce Ecology Index (WEI) 1.0 — Governance and SIOS Read Models

Status: **Pre-production / policy draft**

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

Canonical tables:

- `metric_registry`
- `measurement_observations`
- `dimension_scores`
- `index_scores`
- `interventions`
- `policy_versions`
- `audit_events`
- `production_gate`

Canonical tables remain private. RLS is enabled and ordinary `anon` / `authenticated` access is not granted under the current server-only architecture.

## SIOS read models

Migration `workforce_ecology_sios_read_models_v1` introduced private, `security_invoker` read models:

- `workforce_ecology.sios_wei_current` — latest governed WEI result by organization / operating unit / team.
- `workforce_ecology.sios_wei_dimension_scorecard` — seven-dimension scorecard with evidence completeness and threshold status.
- `workforce_ecology.sios_wei_intervention_queue` — open intervention work queue.
- `workforce_ecology.sios_wei_governance_panel` — calculation version, evidence completeness, governance flags, approvals, and audit freshness.
- `workforce_ecology.sios_wei_production_gate` — current production/pilot authorization state.

These views are not granted to `anon` or `authenticated`. `service_role` has SELECT access for governed server-side SIOS integration.

## Production gate

Migration `workforce_ecology_production_gate_v1` created `WEI-1.0-PRODUCTION-GATE` with status **blocked**.

The gate requires:

1. WEI policy approval.
2. Production identity and authorization mapping.
3. Accountable human reviewers.
4. A limited pilot before controlled scale.
5. No autonomous personnel action.

The database policy row for `WEI-1.0` remains **draft** with no approval reference. No production authorization is asserted by this repository record.

## Validation state

Governance hardening has been validated with transaction-isolated synthetic scenarios, including normal operation, a critical Human Connection dimension, unsustainable high performance / low capacity, and multiple critical human dimensions. Synthetic validation data was rolled back rather than retained.

The SIOS read models currently return no WEI workforce rows because no production workforce observations or index scores have been introduced.

## Institutional sequence

**Formal WEI-1.0 Approval → Production Identity & Authorization Mapping → Human Reviewer Assignment → Limited Pilot → Fairness / Privacy / Signal Review → Institutional Acceptance → Controlled Scale**

## Control principle

> Aggregate strength cannot conceal critical human-system weakness.

WEI provides evidence for accountable human governance; it is not an autonomous workforce authority.
