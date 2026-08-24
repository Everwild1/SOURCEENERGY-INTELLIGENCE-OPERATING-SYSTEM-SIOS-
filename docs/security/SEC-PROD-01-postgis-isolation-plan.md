# SEC-PROD-01 — PostGIS Isolation Plan

## Decision
Do not promote direct ACL mutation of PostGIS-managed `st_estimatedextent` functions. Non-production validation demonstrated that `REVOKE` / `REVOKE ALL` executed through the available project context does not persistently remove the extension-managed `PUBLIC`, `anon`, or `authenticated` EXECUTE ACL entries.

## Confirmed baseline
- PostGIS version: 3.3.7.
- Extension schema: `public`.
- `extrelocatable = false`.
- `spatial_ref_sys` and `st_estimatedextent` are PostGIS extension-managed objects.
- Non-production currently has 105 relations in `public` and 0 in `api`.
- `authenticator` has no manual `pgrst.db_schemas` override in `rolconfig`; hosted Data API exposure is therefore dashboard/platform-managed.
- Removing `public` from exposed schemas now would be a breaking API-surface migration and is not authorized as a surgical security fix.

## Supported remediation path
Supabase documentation states that PostGIS 2.3+ is not normally relocatable. For an existing installation in `public`, the supported alternatives are:
1. destructive dependency-aware drop/recreate/restore into a non-public schema; or
2. Supabase Support-assisted relocation by temporarily enabling extension relocatability, moving the extension, updating it, then restoring `extrelocatable=false`.

For this production environment, use the support-assisted path unless a fully rehearsed backup/drop/recreate/restore plan is separately approved.

## Target architecture
- PostGIS resides in a non-exposed schema such as `extensions` or `gis`.
- `public` remains exposed only until API consumers are inventoried and migrated.
- Longer-term, introduce a dedicated `api` schema and expose only intentional API objects; keep internal tables/helpers and extensions outside exposed schemas.
- Do not disable or remove `public` from Data API exposure until all REST/RPC/GraphQL consumers are inventoried, compatibility-tested, and cut over.

## Required evidence before production relocation
- Supabase Support case/reference and approved relocation procedure.
- Full dependency inventory for PostGIS types, functions, operators, indexes, views, RPCs and application SQL.
- Backup/PITR readiness evidence and rollback procedure.
- Non-production rehearsal or provider-confirmed equivalent.
- Regression tests for spatial queries and dependent services.
- Security advisor before/after evidence.
- Performance advisor before/after evidence.
- Production maintenance/change record and post-change verification.

## Production guardrail
No direct mutation of extension-owned `spatial_ref_sys` or PostGIS function definitions/ACLs is to be promoted from the failed Phase-1 experiment. Production remains unchanged until the supported relocation or API-isolation path is proven.
