# TST Control-to-Code Implementation Map

Parent: #162
Foundation: #163

This manifest is the traceability contract from governance requirement to executable implementation and assurance evidence.

| Control ID | Requirement | Implementation Surface | Test / Evidence | Status |
|---|---|---|---|---|
| TST-CTL-001 | Canonical organization identity | `tst.stewardship_entities.organization_oid -> public.setc_organizations(oid)` | `supabase/tests/tst_foundation_001.sql` | FOUNDATION |
| TST-CTL-002 | Stewardship domain segregation | `tst`, `tst_private`, `tst_audit`, `tst_reporting`, `tst_public`, `tst_api` | schema/grant contract tests | FOUNDATION |
| TST-CTL-003 | Exact financial precision | `numeric(20,2)` fund/financial contract | type contract tests | FOUNDATION |
| TST-CTL-004 | Deny-by-default operational access | RLS + explicit grants | RLS contract tests | FOUNDATION |
| TST-CTL-005 | No anonymous private access | schema/table grants and RLS | negative authorization tests | FOUNDATION |
| TST-CTL-006 | Governed role/permission vocabulary | `tst.roles`, `tst.permissions`, `tst.role_permissions` | reference integrity tests | FOUNDATION |
| TST-CTL-007 | Governed feature activation | `tst.feature_flags` | pilot feature-state tests | FOUNDATION |
| TST-CTL-008 | Tithe election/calculation authority | future controlled RPC + calculation tables | WP03 tests | PLANNED |
| TST-CTL-009 | Restriction compatibility | future fund/restriction/allocation controls | WP04 tests | PLANNED |
| TST-CTL-010 | Beneficiary eligibility | future beneficiary/compliance domain | WP05 tests | PLANNED |
| TST-CTL-011 | Related-party governance | future conflicts/recusals | WP06 tests | PLANNED |
| TST-CTL-012 | Segregation of duties | future approval/execution/reconciliation controls | WP07/WP08 tests | PLANNED |
| TST-CTL-013 | Duplicate payment prevention | future idempotent payment intent | WP08 tests | PLANNED |
| TST-CTL-014 | Evidence immutability/versioning | future evidence metadata + Storage policies | WP09 tests | PLANNED |
| TST-CTL-015 | Append-oriented audit lineage | future `tst_audit` events | WP10 tests | PLANNED |
| TST-CTL-016 | D0-only public transparency | future `tst_public` views | WP11 negative publication tests | PLANNED |
| TST-CTL-017 | Continuous control assurance | future control engine | WP12 tests | PLANNED |
| TST-CTL-018 | MFA for high-risk actions | future AAL2 authorization gates | WP13 tests | PLANNED |
| TST-CTL-019 | P0 production blocking | CI + production readiness contract | WP14/WP15 | PLANNED |

## Mapping rule

Every material TST control must eventually map:

Governance Requirement -> Control ID -> Migration/Object -> RPC/Policy -> Test -> Reporting/Evidence Surface.

A control is not complete merely because a table or policy exists; operating effectiveness requires a passing test and retained evidence.
