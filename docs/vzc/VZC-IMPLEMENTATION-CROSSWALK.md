# Vision Zero Connect — SourceCube Implementation Crosswalk

Status: controlled implementation baseline

Canonical hierarchy:

**SourceEnergy One → SETC → SIOS / SourceCube → VZC Mission Application Domain**

## Boundary

SourceCube/SIOS owns shared intelligence primitives. VZC owns bounded mobility-safety semantics, derived safety state, governed recommendations and mission workflows. VZC does not become the enterprise spatial registry, organization registry, identity authority, logistics operator, healthcare authority or government authority.

## E01 — Domain Foundation & SourceCube Bindings

- `vzc.domain_registry`: mission-domain state; `production_authority=false` at baseline.
- `vzc.source_bindings`: evidence-backed references to authoritative/shared systems.
- `vzc.spatial_bindings`: safety-context projection over SourceCube/SSR spatial identity.
- `vzc.organization_bindings`: relationship projection over SourceCube Organizations/candidate records.
- `vzc.domain_events`: generic governed event envelope separating observation, intelligence, prediction, recommendation, authorization, execution and outcome.

## E02 — Safety Event & Observation Contract

- `vzc.observation_registry`: source observations with quality, confidence and provenance.
- `vzc.safety_events`: correlated mobility-safety events.
- `vzc.safety_event_observations`: evidence graph connecting observations to correlated events.
- `event_state='authority_confirmed'` requires `authority_reference`.
- `event_class in ('authorization','execution')` requires `authority_reference`.

## Trust classes

`observation → derived_intelligence → prediction → recommendation → authorization → execution → outcome`

Movement along this sequence is not automatic. A prediction is not a recommendation; a recommendation is not authorization; authorization is not proof that physical execution occurred.

## Evidence lifecycle

`Concept → Evidence Identified → Validated → Integration Designed → Prototype → Pilot Approved → Pilot Active → Production Approved`

## Security posture

The `vzc` schema is private by default. RLS is enabled on VZC tables as defense in depth. Initial table policies are restricted to `service_role`; public-client access is not enabled by these migrations. Any future Data API exposure requires explicit grants, RLS policy design and a documented application authorization model.

## Canonical controls

Implementation is governed by VZC-000 through VZC-010 and VZC-SC-001. VZC-SC-001 is the controlling SourceCube alignment record.
