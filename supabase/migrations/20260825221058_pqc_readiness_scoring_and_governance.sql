create or replace view pqc.quantum_readiness_summary as
select
  count(*)::int as total_assets,
  count(*) filter (where quantum_vulnerable is true)::int as known_quantum_vulnerable_assets,
  count(*) filter (where quantum_vulnerable is null)::int as unclassified_assets,
  count(*) filter (where harvest_now_decrypt_later_risk in ('high','critical'))::int as high_hndl_assets,
  coalesce(round(avg(migration_priority)::numeric,2),0) as average_migration_priority,
  case when count(*) = 0 then 0 else round((count(*) filter (where quantum_vulnerable is not null)::numeric / count(*)::numeric) * 100,2) end as classification_coverage_pct
from pqc.crypto_assets;

create or replace view pqc.migration_readiness_summary as
select
  count(*)::int as total_items,
  count(*) filter (where migration_stage in ('pqc_ready','verified','legacy_retired'))::int as pqc_ready_or_better,
  count(*) filter (where verification_status = 'passed')::int as verified_items,
  count(*) filter (where quantum_risk in ('high','critical'))::int as high_risk_items,
  case when count(*) = 0 then 0 else round((count(*) filter (where migration_stage in ('pqc_ready','verified','legacy_retired'))::numeric / count(*)::numeric) * 100,2) end as migration_completion_pct
from pqc.migration_register;

create or replace function pqc.record_verification_event(
  p_event_type text,
  p_subject_type text,
  p_subject_ref text,
  p_verification_status text,
  p_correlation_id text,
  p_algorithm_code text default null,
  p_policy_code text default null,
  p_verification_engine text default null,
  p_verifier_identity text default null,
  p_evidence_reference text default null,
  p_result_metadata jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare v_id uuid;
begin
  insert into pqc.verification_events(event_type,subject_type,subject_ref,algorithm_code,policy_code,verification_status,verification_engine,verifier_identity,evidence_reference,correlation_id,result_metadata)
  values(p_event_type,p_subject_type,p_subject_ref,p_algorithm_code,p_policy_code,p_verification_status,p_verification_engine,p_verifier_identity,p_evidence_reference,p_correlation_id,coalesce(p_result_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end; $$;

revoke all on function pqc.record_verification_event(text,text,text,text,text,text,text,text,text,text,jsonb) from public, anon, authenticated;
grant execute on function pqc.record_verification_event(text,text,text,text,text,text,text,text,text,text,jsonb) to service_role;

revoke all on pqc.quantum_readiness_summary, pqc.migration_readiness_summary from anon, authenticated;
grant select on pqc.quantum_readiness_summary, pqc.migration_readiness_summary to service_role;

insert into pqc.verification_events(event_type,subject_type,subject_ref,verification_status,verification_engine,verifier_identity,evidence_reference,correlation_id,result_metadata)
values
('inventory_verification','crypto_asset','Supabase publishable API key','passed','Supabase management inspection','PQ-CGL control plane','Supabase publishable-key inventory','PQC-20260825-001',jsonb_build_object('finding','modern publishable key present')),
('migration_verification','migration_item','Supabase legacy anon API key','pending','PQ-CGL governance review','PQ-CGL control plane','Supabase key migration guidance','PQC-20260825-002',jsonb_build_object('finding','legacy anon remains enabled; deactivate only after dependency validation')),
('security_exception','database_table','public.spatial_ref_sys','exception','Supabase schema inspection','PQ-CGL control plane','RLS advisory','PQC-20260825-003',jsonb_build_object('finding','RLS disabled','remediation_requires_impact_review',true));