# SourceEnergy Insurance — SETC-065 Implementation Roadmap

Status: Architecture → Engineering Readiness

## Canonical hierarchy

SourceEnergy Ecosystem → SourceEnergy Insurance → SETC-065 Insurance Control Plane.

SourceEnergy Insurance is the ecosystem risk-transfer, protection, resilience, and insurance-intelligence layer. SETC-065 remains authoritative for insurance lifecycle controls. The canonical organization parent is `public.setc_organizations.oid` in the SourceEnergy command backend.

## SEI governance stack

- SEI-001 — Institutional Charter & Operating Model
- SEI-002 — Entity, Licensing & Jurisdiction Matrix
- SEI-003 — Ecosystem Risk Taxonomy & SE-RISK-ID
- SEI-004 — Insurance Product & Coverage Matrix
- SEI-005 — Ecosystem Entity/Asset/Transaction Insurance Mapping
- SEI-006 — Broker, Carrier & Reinsurance Architecture
- SEI-007 — Captive Strategy
- SEI-008 — Global Trade, Cargo, Marine & Supply Chain
- SEI-009 — Health, Life & Diaspora Protection
- SEI-010 — Infrastructure, Energy, Climate & Parametric
- SEI-011 — Insurance Intelligence & SETC Integration
- SEI-012 — Institutional Launch & Readiness

## Engineering object graph

`setc_organizations.oid`
→ insurance risk object
→ risk assessment
→ insurance requirement
→ underwriting submission
→ quote
→ policy
→ endorsement
→ premium
→ claim
→ reserve
→ reinsurance program
→ cession/recoverable
→ catastrophe event
→ reconciliation.

## Database tranche A — core lifecycle

1. `setc_insurance_products`
2. `setc_insurance_risk_objects`
3. `setc_insurance_risk_assessments`
4. `setc_insurance_requirements`
5. `setc_insurance_underwriting_submissions`
6. `setc_insurance_quotes`
7. `setc_insurance_policies`
8. `setc_insurance_endorsements`
9. `setc_insurance_premiums`
10. `setc_insurance_claims`

## Database tranche B — risk capital

- claim reserves / IBNR
- reinsurance programs and layers
- cessions
- recoverables
- catastrophe events and exposure aggregation
- insurance reconciliations

## Security contract

Insurance tables in exposed schemas must have RLS enabled. Initial activation is deny-by-default with service-role-only backend access, matching the existing ecosystem security baseline. Do not grant `anon` or generic `authenticated` access until an organization membership/authority contract is explicitly implemented and tested. Any future authenticated policies must be organization-scoped, not merely `TO authenticated`.

Views exposed through the API must use `security_invoker = true`. Privileged `SECURITY DEFINER` functions must not be placed in exposed schemas unless intentionally designed and independently reviewed; execution must be explicitly revoked from inappropriate roles.

## Regulatory boundary

Database state does not create insurance coverage, underwriting authority, claims authority, carrier status, broker status, reinsurance status, or a financial guarantee. Legal coverage remains governed by authorized parties, applicable law, policy wording, binders, endorsements, and authoritative carrier records.

The insurance architecture must not characterize an SBLC, investment, monetization program, trade-platform outcome, token, or other financial instrument as insured or guaranteed absent documentary evidence from an authorized insurer establishing that coverage.

## Release gates

1. Architecture
2. Pre-licensing
3. Partner enabled
4. Limited production
5. Institutional production

No capability may advance a regulatory state solely because software functionality exists.

## Delivery sequence

### INS-E01 — Domain baseline
Create core lifecycle schema, constraints, indexes, timestamps, provenance fields, organization bindings, RLS, and service-role policies.

### INS-E02 — Risk registry
Implement SE-RISK-ID, risk taxonomy, exposure valuation, geography/jurisdiction, peril and mitigation controls.

### INS-E03 — Underwriting
Implement requirements, submissions, evidence, quotes, referrals, authority state, and explicit bind boundary.

### INS-E04 — Policy administration
Implement policies, coverage terms, limits, deductibles, endorsements, renewals, cancellations, certificates and authoritative-record references.

### INS-E05 — Premium and settlement
Implement premium schedules, invoices, receipts, reconciliation references and financial-system boundaries.

### INS-E06 — Claims
Implement FNOL, claim state, evidence, adjuster/authority references, reserves, payments and recovery state.

### INS-E07 — Reinsurance
Implement programs, layers, treaties/facultative placements, cessions, recoverables and counterparty exposure.

### INS-E08 — Catastrophe and parametric
Implement catastrophe events, exposure aggregation and verified trigger observations without allowing oracle data to manufacture contractual entitlement.

### INS-E09 — Insurance intelligence
Implement security-invoker dashboard views and executive KPIs for coverage gaps, insured value, premium, renewals, claims, reserves, concentration and recoverables.

### INS-E10 — Ecosystem adapters
Bind insurance risk objects to logistics, energy, health, WIM and other ecosystem objects through canonical IDs and evidence references.

### INS-E11 — Compliance and authority
Implement jurisdiction, licensing, carrier/broker/reinsurer authority evidence and activation gates.

### INS-E12 — Production readiness
Complete pgTAP/RLS tests, database advisors, reconciliation tests, audit/event verification, CI, operational runbooks and release approval.

## Definition of done

A tranche is complete only when schema, constraints, RLS, tests, auditability, documentation, advisor review and rollback/recovery expectations are satisfied. Production activation additionally requires the corresponding legal/regulatory authority and partner evidence.