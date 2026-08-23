# SourceEnergy Tithe Stewardship Trust (TST)

Status: repository activation / foundation implementation
Parent epic: #162
Foundation work package: #163

## Purpose

TST is the SIOS bounded domain for a formally segregated tithe stewardship fund/trust architecture with defined beneficiaries, authorized uses, fiduciary controls, evidence, audit trails, reconciliation, and reporting.

## Authority boundary

Repository code implements approved governance; it does not independently establish legal trust status, tax treatment, charitable qualification, trustee powers, beneficiary eligibility policy, or religious doctrine.

## Canonical identity integration

TST MUST reuse `public.setc_organizations` as the canonical organization identity registry. TST tables may reference SETC organization OIDs but MUST NOT create a competing organization master.

## Data boundaries

- `tst`: operational stewardship domain
- `tst_private`: high-sensitivity records and future private helpers
- `tst_audit`: append-oriented assurance/audit domain
- `tst_reporting`: governed internal reporting
- `tst_public`: explicitly approved D0 transparency surface only
- `tst_api`: deliberately exposed API/RPC surface only

## Initial pilot boundary

Enabled for pilot: core stewardship records and fiat/cash workflow preparation.

Disabled by default: public reporting, international high-risk beneficiary flows, digital assets, Source Coin, and SBLC functionality.

## Engineering rules

1. Deny by default.
2. Use exact numeric types for authoritative financial amounts.
3. Server/database controls are authoritative; browser logic is not.
4. RLS and grants are separate controls and must both be reviewed.
5. User-editable metadata is never fiduciary authorization.
6. Evidence is versioned; verified evidence is not silently overwritten.
7. Audit history is not mutable by ordinary application roles.
8. Production activation requires the TST acceptance and certification gates.

## Delivery sequence

PR-TST-01 Foundation -> stewardship ledger -> beneficiaries/governance -> distributions -> treasury -> evidence/audit -> reporting -> continuous assurance -> security hardening -> pilot certification.
