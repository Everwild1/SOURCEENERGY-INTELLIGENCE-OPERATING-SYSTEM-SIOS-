# SETC Phase II-A — Production Hardening & Quality Gates

Parent program: GitHub Issue #42  
Workstream: GitHub Issue #43

## Purpose

Phase II-A hardens the closed Epics 1–37 SETC Organizations baseline without introducing a new institutional governance domain. The objective is deterministic software quality: invalid inputs fail explicitly, canonical values round-trip predictably, normalization behavior remains stable, and the package-level public API does not drift silently.

## Deterministic quality gates

### QG-1 — Canonical identifier validation
`SETCIdentifier` must reject malformed, incomplete, incorrectly cased, or non-hex organization identifiers. A newly minted identifier must reconstruct from its string representation without information loss.

### QG-2 — Required organization identity
`Organization` must reject a blank legal name after whitespace normalization.

### QG-3 — Normalization invariants
Organization legal names and aliases must retain the existing normalization contract: surrounding whitespace is removed and blank aliases are discarded.

### QG-4 — Public API stability
Representative high-value SETC Organizations symbols spanning identity, policy, risk, compliance, adjudication, judgment execution, and assurance must remain available through `setc.organizations` and its public export registry.

### QG-5 — Export hygiene
The public export registry must contain no duplicate or private names.

### QG-6 — Boundary preservation
Phase II-A must not modify or couple to `ssr/`. It introduces no legal authority, accreditation, credential, financial entitlement, or institutional endorsement semantics.

## Release control

Implementation begins from the Epic 37 release-closure baseline on `main`. The implementation pull request remains Draft until SETC Core CI reports success. Promotion and final integration use the established review and squash-merge control path.

## Evidence

The executable evidence for these gates is `tests/test_setc_phase_2a_production_hardening.py`. SETC Core CI is the authoritative automated release gate for the implementation head.