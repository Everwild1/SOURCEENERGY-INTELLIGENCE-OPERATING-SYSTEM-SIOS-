create or replace view pqc.readiness_summary as
select
  (select count(*) from pqc.crypto_assets) as crypto_assets,
  (select count(*) from pqc.migration_register) as migration_items,
  (select count(*) from pqc.verification_events) as verification_events,
  (select round(100.0 * count(*) filter (where quantum_vulnerable is not null) / nullif(count(*),0),2) from pqc.crypto_assets) as classification_coverage_pct,
  (select round(100.0 * count(*) filter (where migration_stage in ('pqc_ready','verified','legacy_retired')) / nullif(count(*),0),2) from pqc.migration_register) as migration_completion_pct;

revoke all on pqc.readiness_summary from anon, authenticated;
grant select on pqc.readiness_summary to service_role;

insert into pqc.verification_events (verification_type, subject_type, subject_id, expected_state, observed_state, result, verifier, evidence_reference, notes)
select 'readiness_baseline','program','PQ-CGL',jsonb_build_object('target','measured-not-assumed'),jsonb_build_object('crypto_assets',crypto_assets,'migration_items',migration_items,'classification_coverage_pct',classification_coverage_pct,'migration_completion_pct',migration_completion_pct),'passed','SourceEnergy PQ-CGL','pqc.readiness_summary','Baseline readiness score established from verified database state.'
from pqc.readiness_summary;