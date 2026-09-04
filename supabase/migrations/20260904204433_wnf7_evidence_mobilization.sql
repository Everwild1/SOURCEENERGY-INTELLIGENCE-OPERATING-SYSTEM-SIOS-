create unique index if not exists evidence_items_scenario_ref_uidx
  on wnf7.evidence_items(scenario_code,evidence_ref);

comment on index wnf7.evidence_items_scenario_ref_uidx is
  'Prevents duplicate evidence references for a WNF-7 pilot scenario.';

insert into wnf7.evidence_items(
  scenario_code,
  evidence_ref,
  source_system,
  content_sha256,
  freshness_status,
  validation_status,
  observed_at,
  metadata
)
select
  scenario_code,
  'controlled://SRC-011/scenario/' || scenario_code,
  'SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE',
  '2af020c74f36472f021e27e2fa549f47012ae8ba39bd3dad0fe39f0db4dbe98c',
  'PENDING',
  'PENDING',
  '2026-09-04T16:11:22.304Z'::timestamptz,
  jsonb_build_object(
    'evidence_stage','CANDIDATE',
    'package_ref','SRC-011',
    'control_register_ref','SRC-013',
    'package_version','1.3',
    'package_classification','CONTROLLED_PILOT_TEST_EVIDENCE',
    'authority_posture','DOES_NOT_CONFER_AUTHORITY',
    'execution_allowed',false,
    'integrity_status','SHA256_MANIFEST_MATCH',
    'hash_scope','CHARTER_RESULTS_ARTIFACT',
    'package_manifest_sha256','cac5cd8757e52af04b6bed409879e70f6fd5abdc1e7c3842f4411e77580c0811',
    'charter_results_sha256','2af020c74f36472f021e27e2fa549f47012ae8ba39bd3dad0fe39f0db4dbe98c',
    'required_evidence',required_evidence,
    'reviewer_role_code',reviewer_role_code,
    'expected_automated_state',expected_automated_state,
    'decision_eligibility',decision_eligibility,
    'substantive_validation','PENDING_HUMAN_REVIEW'
  )
from wnf7.pilot_scenarios
where pilot_code='PILOT-7D-001' and active
on conflict (scenario_code,evidence_ref) do nothing;

create view wnf7.evidence_mobilization_readiness with(security_invoker=true) as
with mobilization as (
  select
    g.pilot_code,
    g.gate_code,
    g.gate_state,
    g.production_authorized,
    (select count(*) from wnf7.reviewer_roles where required) reviewer_target,
    (select count(*) from wnf7.reviewer_assignments r
      where r.pilot_code=g.pilot_code and r.mobilization_status='ACCEPTED') accepted_reviewers,
    (select count(*) from wnf7.pilot_scenarios s
      where s.pilot_code=g.pilot_code and s.active) scenario_target,
    (select count(distinct e.scenario_code)
      from wnf7.evidence_items e
      join wnf7.pilot_scenarios s using(scenario_code)
      where s.pilot_code=g.pilot_code
        and s.active
        and e.source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
        and e.metadata->>'evidence_stage'='CANDIDATE'
        and e.metadata->>'package_ref'='SRC-011') candidate_evidence_packets,
    (select count(distinct e.scenario_code)
      from wnf7.evidence_items e
      join wnf7.pilot_scenarios s using(scenario_code)
      where s.pilot_code=g.pilot_code
        and s.active
        and e.source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
        and e.validation_status='PENDING') pending_evidence_packets,
    (select count(distinct e.scenario_code)
      from wnf7.evidence_items e
      join wnf7.pilot_scenarios s using(scenario_code)
      where s.pilot_code=g.pilot_code
        and s.active
        and e.source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
        and e.metadata->>'evidence_stage'='CANDIDATE'
        and e.metadata->>'integrity_status'='SHA256_MANIFEST_MATCH'
        and e.metadata->>'package_manifest_sha256'='cac5cd8757e52af04b6bed409879e70f6fd5abdc1e7c3842f4411e77580c0811'
        and e.content_sha256=e.metadata->>'charter_results_sha256') integrity_matched_candidates,
    (select count(distinct e.scenario_code)
      from wnf7.evidence_items e
      join wnf7.pilot_scenarios s using(scenario_code)
      where s.pilot_code=g.pilot_code
        and s.active
        and e.validation_status='VALIDATED') validated_evidence_packets,
    (select count(distinct d.scenario_code)
      from wnf7.adjudication_decisions d
      join wnf7.pilot_scenarios s using(scenario_code)
      where s.pilot_code=g.pilot_code
        and s.active
        and d.decision_status='COMPLETE') completed_decisions
  from wnf7.release_gates g
)
select
  mobilization.*,
  case
    when accepted_reviewers=reviewer_target
      and validated_evidence_packets=scenario_target
      and completed_decisions=scenario_target
      then 'READY_FOR_AUTHORITY_REVIEW'
    when candidate_evidence_packets=scenario_target
      and integrity_matched_candidates=scenario_target
      then 'MOBILIZED_PENDING_HUMAN_VALIDATION'
    else 'HOLD_INCOMPLETE'
  end mobilization_state
from mobilization;

revoke all on wnf7.evidence_mobilization_readiness from public,anon,authenticated;
grant select on wnf7.evidence_mobilization_readiness to service_role;

comment on view wnf7.evidence_mobilization_readiness is
  'Tracks candidate technical evidence mobilization. SHA-256 integrity does not constitute freshness validation, adjudication, authority, gate passage, or production authorization.';
