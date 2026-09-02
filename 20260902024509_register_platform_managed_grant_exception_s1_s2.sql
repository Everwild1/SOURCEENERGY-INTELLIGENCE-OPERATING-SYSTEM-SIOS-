-- Ecosystem-level risk exception for audit findings S1/S2 residuals.
-- Verified 2026-09-01: public.spatial_ref_sys (owner supabase_admin) carries
-- full-DML grants to anon/authenticated granted BY supabase_admin; the three
-- public.st_estimatedextent overloads carry EXECUTE grants by the same grantor.
-- PostgreSQL permits only the grantor to revoke; migration
-- security_advisor_remediation_phase1 attempted revoke (silent no-op) and a
-- guarded RLS enable (blocked: not owner). Resolution path: Supabase support
-- ticket requesting supabase_admin-level revoke or RLS enable.

insert into dhn_ops.release_risk_exceptions(
  exception_code, domain, control_area, ownership_boundary, status, severity,
  description, compensating_controls, evidence, review_due_at)
values(
  'ECO-S1S2-POSTGIS-MANAGED-GRANTS',
  'shared_platform',
  'managed_postgis_grant_surface',
  'Grants issued by supabase_admin on extension-owned objects; postgres role cannot revoke another grantor''s grants',
  'open',
  'high',
  'Audit findings S1/S2 residual: anon and authenticated hold supabase_admin-granted full DML on public.spatial_ref_sys (RLS disabled, table API-exposed and writable) and EXECUTE on public.st_estimatedextent overloads. Non-destructive remediation attempted and verified ineffective on 2026-09-01 (migration security_advisor_remediation_phase1). Status open, not accepted: anon write access to coordinate-reference metadata is an integrity exposure; resolution requires platform-side action.',
  jsonb_build_object(
    'search_path_pinning_completed', true,
    'app_schemas_default_deny_rls', true,
    'no_application_dependency_on_spatial_ref_sys_writes', true,
    'monitoring', 'periodic advisor re-run'),
  jsonb_build_object(
    'grantor_verified', 'supabase_admin',
    'owner_verified', 'supabase_admin',
    'revoke_attempted_via', 'security_advisor_remediation_phase1',
    'rls_enable_blocked', 'insufficient_privilege (not owner)',
    'resolution_path', 'Supabase support ticket: revoke anon/authenticated on spatial_ref_sys and st_estimatedextent, or enable RLS, as supabase_admin',
    'related_exception', 'E11-R2-POSTGIS-MANAGED'),
  now() + interval '30 days')
on conflict (exception_code) do update set
  status = excluded.status,
  severity = excluded.severity,
  description = excluded.description,
  compensating_controls = excluded.compensating_controls,
  evidence = excluded.evidence,
  review_due_at = excluded.review_due_at,
  updated_at = now();
