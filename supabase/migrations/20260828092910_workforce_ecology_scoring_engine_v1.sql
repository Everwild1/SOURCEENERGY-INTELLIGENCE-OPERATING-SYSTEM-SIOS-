insert into workforce_ecology.metric_registry
(dimension_code, metric_name, description, evidence_class, aggregation_method, normalization_method, weight_within_dimension, minimum_cohort_size, calculation_version, governance_status)
values
('productive_performance','delivery_reliability','Synthetic-ready operational measure of delivery reliability.','operational_telemetry','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('productive_performance','quality_execution','Synthetic-ready operational measure of quality and execution.','structured_process_data','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('human_connection','manager_peer_connection','Aggregated cadence of meaningful manager and peer connection.','voluntary_aggregated_pulse','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('human_connection','collaboration_participation','Aggregated participation in purposeful collaboration.','collaboration_indicator','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('social_capital','cross_functional_network_strength','Aggregated cross-functional relationship strength.','network_indicator','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('social_capital','knowledge_exchange','Aggregated knowledge-sharing and reciprocity indicator.','structured_process_data','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('development','mentorship_coverage','Aggregated mentorship coverage.','learning_development_record','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('development','capability_growth','Aggregated skill and capability expansion.','learning_development_record','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('belonging','purpose_alignment','Voluntary aggregated purpose-alignment indicator.','voluntary_aggregated_pulse','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('belonging','participation_inclusion','Aggregated participation and inclusion indicator.','structured_process_data','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('sustainable_capacity','workload_sustainability','Aggregated workload sustainability indicator; excludes clinical data.','operational_telemetry','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('sustainable_capacity','continuity_retention','Aggregated continuity and avoidable-retention-risk indicator.','retention_continuity_signal','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('community_contribution','ecosystem_participation','Aggregated participation in ecosystem-building activity.','community_participation_record','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved'),
('community_contribution','community_value_creation','Aggregated community or enterprise-development contribution.','community_participation_record','weighted_average','0_to_100_direct',0.50,5,'WEI-1.0','approved')
on conflict (dimension_code, metric_name, calculation_version) do nothing;

create or replace function workforce_ecology.calculate_wei_v1(
  p_organization_id text,
  p_operating_unit_id text,
  p_team_id text,
  p_period_start date,
  p_period_end date,
  p_calculation_version text default 'WEI-1.0'
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_weights jsonb;
  v_index_score numeric(6,3);
  v_band text;
  v_lowest_dimension text;
  v_lowest_score numeric(6,3);
  v_intervention boolean;
  v_index_id uuid;
  v_dimension_count integer;
begin
  if p_period_end < p_period_start then
    raise exception 'period_end must be on or after period_start';
  end if;

  select weight_configuration
    into v_weights
  from workforce_ecology.policy_versions
  where version_name = p_calculation_version
    and status in ('draft','approved')
  order by created_at desc
  limit 1;

  if v_weights is null then
    raise exception 'No active draft/approved WEI policy found for version %', p_calculation_version;
  end if;

  delete from workforce_ecology.dimension_scores ds
   where ds.organization_id = p_organization_id
     and ds.operating_unit_id is not distinct from p_operating_unit_id
     and ds.team_id is not distinct from p_team_id
     and ds.period_start = p_period_start
     and ds.period_end = p_period_end
     and ds.calculation_version = p_calculation_version;

  delete from workforce_ecology.index_scores ix
   where ix.organization_id = p_organization_id
     and ix.operating_unit_id is not distinct from p_operating_unit_id
     and ix.team_id is not distinct from p_team_id
     and ix.period_start = p_period_start
     and ix.period_end = p_period_end
     and ix.calculation_version = p_calculation_version;

  insert into workforce_ecology.dimension_scores
  (organization_id, operating_unit_id, team_id, period_start, period_end, dimension_code, score_0_100, evidence_completeness, trend_delta, calculation_version, review_status)
  select
    p_organization_id,
    p_operating_unit_id,
    p_team_id,
    p_period_start,
    p_period_end,
    mr.dimension_code,
    round((sum(mo.normalized_value * mr.weight_within_dimension) / nullif(sum(mr.weight_within_dimension),0))::numeric,3),
    round((count(distinct mo.metric_id)::numeric / nullif((select count(*) from workforce_ecology.metric_registry mr2 where mr2.dimension_code = mr.dimension_code and mr2.calculation_version = p_calculation_version and mr2.governance_status = 'approved'),0) * 100)::numeric,3),
    null,
    p_calculation_version,
    'pending'
  from workforce_ecology.metric_registry mr
  join workforce_ecology.measurement_observations mo on mo.metric_id = mr.metric_id
  where mr.calculation_version = p_calculation_version
    and mr.governance_status = 'approved'
    and mo.organization_id = p_organization_id
    and mo.operating_unit_id is not distinct from p_operating_unit_id
    and mo.team_id is not distinct from p_team_id
    and mo.period_start = p_period_start
    and mo.period_end = p_period_end
    and mo.quality_status = 'validated'
    and mo.normalized_value is not null
  group by mr.dimension_code;

  select count(*) into v_dimension_count
  from workforce_ecology.dimension_scores ds
  where ds.organization_id = p_organization_id
    and ds.operating_unit_id is not distinct from p_operating_unit_id
    and ds.team_id is not distinct from p_team_id
    and ds.period_start = p_period_start
    and ds.period_end = p_period_end
    and ds.calculation_version = p_calculation_version;

  if v_dimension_count <> 7 then
    raise exception 'WEI calculation requires all 7 dimensions; found %', v_dimension_count;
  end if;

  select round(sum(ds.score_0_100 * ((v_weights ->> ds.dimension_code)::numeric))::numeric,3)
    into v_index_score
  from workforce_ecology.dimension_scores ds
  where ds.organization_id = p_organization_id
    and ds.operating_unit_id is not distinct from p_operating_unit_id
    and ds.team_id is not distinct from p_team_id
    and ds.period_start = p_period_start
    and ds.period_end = p_period_end
    and ds.calculation_version = p_calculation_version;

  select ds.dimension_code, ds.score_0_100
    into v_lowest_dimension, v_lowest_score
  from workforce_ecology.dimension_scores ds
  where ds.organization_id = p_organization_id
    and ds.operating_unit_id is not distinct from p_operating_unit_id
    and ds.team_id is not distinct from p_team_id
    and ds.period_start = p_period_start
    and ds.period_end = p_period_end
    and ds.calculation_version = p_calculation_version
  order by ds.score_0_100 asc, ds.dimension_code
  limit 1;

  v_band := case
    when v_index_score >= 85 then 'flourishing'
    when v_index_score >= 70 then 'resilient'
    when v_index_score >= 55 then 'watch'
    when v_index_score >= 40 then 'intervention'
    else 'critical'
  end;

  v_intervention := v_lowest_score < 40 or v_index_score < 55;

  insert into workforce_ecology.index_scores
  (organization_id, operating_unit_id, team_id, period_start, period_end, wei_score, band, lowest_dimension, intervention_flag, calculation_version)
  values
  (p_organization_id, p_operating_unit_id, p_team_id, p_period_start, p_period_end, v_index_score, v_band, v_lowest_dimension, v_intervention, p_calculation_version)
  returning index_score_id into v_index_id;

  insert into workforce_ecology.audit_events
  (event_type, organization_id, operating_unit_id, team_id, period_start, period_end, calculation_version, evidence_lineage_reference, human_approval_state, payload)
  values
  ('WEI_SCORE_CALCULATED', p_organization_id, p_operating_unit_id, p_team_id, p_period_start, p_period_end, p_calculation_version,
   'workforce_ecology.measurement_observations', 'pending',
   jsonb_build_object('index_score_id',v_index_id,'wei_score',v_index_score,'band',v_band,'lowest_dimension',v_lowest_dimension,'lowest_score',v_lowest_score,'intervention_flag',v_intervention));

  insert into workforce_ecology.audit_events
  (event_type, organization_id, operating_unit_id, team_id, period_start, period_end, calculation_version, evidence_lineage_reference, human_approval_state, payload)
  select
    'WEI_DIMENSION_THRESHOLD_BREACHED', p_organization_id, p_operating_unit_id, p_team_id, p_period_start, p_period_end, p_calculation_version,
    'workforce_ecology.dimension_scores', 'pending',
    jsonb_build_object('dimension_code',ds.dimension_code,'score',ds.score_0_100,'threshold',40)
  from workforce_ecology.dimension_scores ds
  where ds.organization_id = p_organization_id
    and ds.operating_unit_id is not distinct from p_operating_unit_id
    and ds.team_id is not distinct from p_team_id
    and ds.period_start = p_period_start
    and ds.period_end = p_period_end
    and ds.calculation_version = p_calculation_version
    and ds.score_0_100 < 40;

  return v_index_id;
end;
$$;

revoke execute on function workforce_ecology.calculate_wei_v1(text,text,text,date,date,text) from public, anon, authenticated;
grant execute on function workforce_ecology.calculate_wei_v1(text,text,text,date,date,text) to service_role;
alter default privileges for role postgres in schema workforce_ecology revoke execute on functions from public, anon, authenticated;

