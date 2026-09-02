create or replace view workforce_ecology.sios_wei_current
with (security_invoker = true)
as
select distinct on (organization_id, operating_unit_id, team_id)
  index_score_id, organization_id, operating_unit_id, team_id,
  period_start, period_end, wei_score, raw_band, governed_band,
  lowest_dimension, lowest_dimension_score, intervention_flag,
  governance_flags, calculation_version, calculated_at, approved_at,
  approval_reference
from workforce_ecology.index_scores
order by organization_id, operating_unit_id, team_id, period_end desc, calculated_at desc;

create or replace view workforce_ecology.sios_wei_dimension_scorecard
with (security_invoker = true)
as
select ds.organization_id, ds.operating_unit_id, ds.team_id,
  ds.period_start, ds.period_end, ds.dimension_code, ds.score_0_100,
  ds.evidence_completeness, ds.trend_delta, ds.calculation_version,
  ds.calculated_at, ds.review_status,
  case when ds.score_0_100 < 40 then true else false end as threshold_breach
from workforce_ecology.dimension_scores ds;

create or replace view workforce_ecology.sios_wei_intervention_queue
with (security_invoker = true)
as
select intervention_id, organization_id, operating_unit_id, team_id,
  trigger_dimension, trigger_score, intervention_type, action_owner,
  opened_at, target_review_at, status, outcome_summary, closed_at
from workforce_ecology.interventions
where status not in ('closed','cancelled');

create or replace view workforce_ecology.sios_wei_governance_panel
with (security_invoker = true)
as
select ix.index_score_id, ix.organization_id, ix.operating_unit_id, ix.team_id,
  ix.period_start, ix.period_end, ix.calculation_version, ix.calculated_at,
  ix.approved_at, ix.approval_reference, ix.governance_flags,
  min(ds.evidence_completeness) as minimum_dimension_evidence_completeness,
  avg(ds.evidence_completeness) as average_dimension_evidence_completeness,
  max(ae.occurred_at) as latest_audit_event_at
from workforce_ecology.index_scores ix
left join workforce_ecology.dimension_scores ds
  on ds.organization_id=ix.organization_id
 and ds.operating_unit_id is not distinct from ix.operating_unit_id
 and ds.team_id is not distinct from ix.team_id
 and ds.period_start=ix.period_start and ds.period_end=ix.period_end
 and ds.calculation_version=ix.calculation_version
left join workforce_ecology.audit_events ae
  on ae.organization_id=ix.organization_id
 and ae.operating_unit_id is not distinct from ix.operating_unit_id
 and ae.team_id is not distinct from ix.team_id
 and ae.period_start=ix.period_start and ae.period_end=ix.period_end
 and ae.calculation_version=ix.calculation_version
group by ix.index_score_id, ix.organization_id, ix.operating_unit_id, ix.team_id,
  ix.period_start, ix.period_end, ix.calculation_version, ix.calculated_at,
  ix.approved_at, ix.approval_reference, ix.governance_flags;

revoke all on workforce_ecology.sios_wei_current from public, anon, authenticated;
revoke all on workforce_ecology.sios_wei_dimension_scorecard from public, anon, authenticated;
revoke all on workforce_ecology.sios_wei_intervention_queue from public, anon, authenticated;
revoke all on workforce_ecology.sios_wei_governance_panel from public, anon, authenticated;
grant select on workforce_ecology.sios_wei_current to service_role;
grant select on workforce_ecology.sios_wei_dimension_scorecard to service_role;
grant select on workforce_ecology.sios_wei_intervention_queue to service_role;
grant select on workforce_ecology.sios_wei_governance_panel to service_role;
