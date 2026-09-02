# SIOS Migration Reconciliation Package — 2026-09-01

**Source of extraction:** `supabase_migrations.schema_migrations` on project `SourceEnergy-command-backend` (veopccdltsklczlmdbri), read 2026-09-01.
**Target:** `Everwild1/SOURCEENERGY-INTELLIGENCE-OPERATING-SYSTEM-SIOS-` → `supabase/migrations/`
**Contents:** 336 migration files (2,062,836 bytes) — every live-applied migration whose version stamp is absent from the repository — plus `manifest.csv` classifying each file.

Evidence note: file contents are the statements recorded by Supabase at apply time. Formatting or comments may differ from originally authored SQL; the applied statements are the operative record.

## Reconciliation state (verified)

| Metric | Value |
|---|---|
| Live-applied migrations | 368 |
| Repo migration files (before this package) | 65 (64 unique stamps) |
| Repo stamps matching live history | 32 |
| **Class A** — live-applied, absent from repo (this package, incl. Class B live-stamps) | **336** |
| **Class B** — same logical name in repo under a *different* stamp | 15 |
| **Class C** — repo files with *no* live application record | 33 |

## Class B (15) — live stamp is canonical; delete the repo-stamped duplicate
The live-applied versions are included in this package. Their repo counterparts (eco_e04/ph01/ph02, hei_build_001–008, hei_security_hardening_001, ins_e09/e10/e12) carry stamps production never recorded. Keeping both will cause the Supabase CLI to treat the repo-stamped copies as unapplied and attempt re-application. **Remove the 15 repo-stamped duplicates when merging this package.**

## Class C (33) — require explicit disposition before merge
1. **15 Class-B duplicates** — delete (above).
2. **TST series (9 files, `tst_foundation_001` … `tst_oversight_compliance_008`)** — tracked in Git with 9 dedicated CI workflows, but **no `tst` schema exists in the database**. An entire domain is version-controlled and CI-gated yet never deployed. Decide: apply deliberately (and record), or move to a clearly labeled `supabase/unapplied/` staging directory so the migrations directory states only truth.
3. **Insurance e01–e08 (8 files)** — no live application records exist under any stamp, yet the `setc_insurance_*` tables exist in production. Most probable cause: DDL applied via SQL editor without migration recording. Review whether these files match live structure (`supabase db diff`), then either back-record or supersede.
4. **`revolution_wealth_governed_registry` / `_registry_authorization_api` (2 files)** — probable logical equivalents of the differently-named live migrations `extend_revolution_wealth_capital_registry` / `revolution_wealth_registry_authorization`. Review and supersede one lineage.

## Hard defect to fix in the same commit
**Version-stamp collision:** two repo files share stamp `20260823090000` (`hei_security_hardening_001` and `tst_foundation_001`). Duplicate stamps break CLI ordering guarantees. The hei file is deleted under Class B; restamp the tst file if retained.

## Merge procedure (reconciliation branch)
1. `git checkout -b reconcile/supabase-migrations-2026-09-01`
2. Copy `migrations/*.sql` into `supabase/migrations/`.
3. Delete the 15 Class-B repo-stamped duplicates; disposition the remaining Class-C files per above.
4. Verification gate: `supabase db diff --linked` must return **empty** (or only the reviewed ins_e01–e08 deltas). Do not merge until it does.
5. Commit with the manifest, open a PR, and record the PR number against audit finding **G1**.
6. Going forward: all DDL through `supabase migration new` / `db push` only — no dashboard DDL.

## Boundary statement
This package restores version-control custody of internally authored schema. It evidences internal system state only and does not represent acceptance or implementation by any bank, regulator, payment network, or external institution.
