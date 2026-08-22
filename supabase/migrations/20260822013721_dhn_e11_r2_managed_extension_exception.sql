create table if not exists dhn_ops.release_risk_exceptions (
  risk_exception_id uuid primary key default gen_random_uuid(), exception_code text not null unique, domain text not null, control_area text not null,
  ownership_boundary text not null, status text not null check (status in ('open','accepted','mitigated','closed')), severity text not null check (severity in ('low','medium','high','critical')),
  description text not null, compensating_controls jsonb not null default '{}'::jsonb, evidence jsonb not null default '{}'::jsonb,
  review_due_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table dhn_ops.release_risk_exceptions enable row level security;
revoke all privileges on dhn_ops.release_risk_exceptions from public,anon,authenticated;
grant all privileges on dhn_ops.release_risk_exceptions to service_role;
create policy release_risk_exceptions_service_role on dhn_ops.release_risk_exceptions for all to service_role using (true) with check (true);
insert into dhn_ops.release_risk_exceptions(exception_code,domain,control_area,ownership_boundary,status,severity,description,compensating_controls,evidence,review_due_at)
values('E11-R2-POSTGIS-MANAGED','shared_platform','managed_postgis_extension_surface','Supabase-managed extension objects owned by supabase_admin','accepted','medium','Supabase security advisor continues to report public-schema/PostGIS findings on managed extension objects. DHN does not own these objects and destructive ownership or extension relocation changes are out of scope for DHN release. The exception applies only to managed PostGIS findings and does not waive DHN-owned schema controls.',jsonb_build_object('dhn_private_schemas',true,'dhn_tables_rls_enabled',true,'direct_anon_authenticated_table_access_revoked',true,'edge_functions_jwt_protected',true,'phi_biometric_blockchain_boundary_enforced',true,'settlement_privacy_boundary_enforced',true,'audit_attestation_chain_enabled',true),jsonb_build_object('advisor_scope','public.spatial_ref_sys, public PostGIS extension placement, public.st_estimatedextent overloads','owner','supabase_admin','attempted_non_destructive_remediation',true,'ownership_change_not_performed',true),now()+interval '90 days')
on conflict (exception_code) do update set status='accepted',updated_at=now(),compensating_controls=excluded.compensating_controls,evidence=excluded.evidence,review_due_at=excluded.review_due_at;
