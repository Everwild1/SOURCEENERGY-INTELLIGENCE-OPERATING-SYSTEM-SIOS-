alter table workforce_ecology.index_scores
  add column if not exists raw_band text,
  add column if not exists governed_band text,
  add column if not exists lowest_dimension_score numeric(6,3),
  add column if not exists governance_flags jsonb not null default '[]'::jsonb;

update workforce_ecology.index_scores
set raw_band = coalesce(raw_band, band),
    governed_band = coalesce(governed_band, band)
where raw_band is null or governed_band is null;

update workforce_ecology.metric_registry
set evidence_class = 'structured_process_data'
where calculation_version='WEI-1.0' and metric_name='mentorship_coverage';

update workforce_ecology.metric_registry
set evidence_class = 'structured_process_data'
where calculation_version='WEI-1.0' and metric_name='community_value_creation';

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
as $function$
declare
  v_weights jsonb;
  v_index_score numeric(6,3);
  v_raw_band text;
  v_governed_band text;
  v_lowest_dimension text;
  v_lowest_score numeric(6,3);
  v_intervention boolean;
  v_index_id uuid;
  v_dimension_count integer;
  v_incomplete_count integer;
  v_evidence_class_fail_count integer;
  v_critical_human_count integer;
  v_pp numeric(6,3);
  v_cap numeric(6,3);
  v_flags jsonb := '[]'::jsonb;
begin
  if p_period_end < p_period_start then raise exception 'period_end must be on or after period_start'; end if;

  select weight_configuration into v_weights
  from workforce_ecology.policy_versions
  where version_name=p_calculation_version and status in ('draft','approved')
  order by created_at desc limit 1;
  if v_weights is null then raise exception 'No active draft/approved WEI policy found for version %', p_calculation_version; end if;

  delete from workforce_ecology.dimension_scores ds where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version;
  delete from workforce_ecology.index_scores ix where ix.organization_id=p_organization_id and ix.operating_unit_id is not distinct from p_operating_unit_id and ix.team_id is not distinct from p_team_id and ix.period_start=p_period_start and ix.period_end=p_period_end and ix.calculation_version=p_calculation_version;

  insert into workforce_ecology.dimension_scores
  (organization_id,operating_unit_id,team_id,period_start,period_end,dimension_code,score_0_100,evidence_completeness,trend_delta,calculation_version,review_status)
  select p_organization_id,p_operating_unit_id,p_team_id,p_period_start,p_period_end,mr.dimension_code,
    round((sum(mo.normalized_value*mr.weight_within_dimension)/nullif(sum(mr.weight_within_dimension),0))::numeric,3),
    round((count(distinct mo.metric_id)::numeric/nullif((select count(*) from workforce_ecology.metric_registry mr2 where mr2.dimension_code=mr.dimension_code and mr2.calculation_version=p_calculation_version and mr2.governance_status='approved'),0)*100)::numeric,3),
    null,p_calculation_version,'pending'
  from workforce_ecology.metric_registry mr
  join workforce_ecology.measurement_observations mo on mo.metric_id=mr.metric_id
  where mr.calculation_version=p_calculation_version and mr.governance_status='approved'
    and mo.organization_id=p_organization_id and mo.operating_unit_id is not distinct from p_operating_unit_id and mo.team_id is not distinct from p_team_id
    and mo.period_start=p_period_start and mo.period_end=p_period_end and mo.quality_status='validated' and mo.normalized_value is not null
  group by mr.dimension_code;

  select count(*), count(*) filter (where evidence_completeness < 100)
  into v_dimension_count,v_incomplete_count from workforce_ecology.dimension_scores ds
  where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version;
  if v_dimension_count<>7 then raise exception 'WEI calculation requires all 7 dimensions; found %',v_dimension_count; end if;
  if v_incomplete_count>0 then raise exception 'WEI calculation requires 100%% approved-metric evidence completeness for WEI-1.0 baseline; incomplete dimensions: %',v_incomplete_count; end if;

  select count(*) into v_evidence_class_fail_count from (
    select dimension_code from workforce_ecology.metric_registry where calculation_version=p_calculation_version and governance_status='approved'
    group by dimension_code having count(distinct evidence_class)<2
  ) q;
  if v_evidence_class_fail_count>0 then raise exception 'WEI registry requires at least 2 evidence classes per dimension; failing dimensions: %',v_evidence_class_fail_count; end if;

  select round(sum(ds.score_0_100*((v_weights->>ds.dimension_code)::numeric))::numeric,3) into v_index_score
  from workforce_ecology.dimension_scores ds where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version;

  select dimension_code,score_0_100 into v_lowest_dimension,v_lowest_score from workforce_ecology.dimension_scores ds
  where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version order by score_0_100,dimension_code limit 1;

  select count(*) filter(where dimension_code in ('human_connection','belonging','sustainable_capacity') and score_0_100<40),
         max(score_0_100) filter(where dimension_code='productive_performance'), max(score_0_100) filter(where dimension_code='sustainable_capacity')
  into v_critical_human_count,v_pp,v_cap from workforce_ecology.dimension_scores ds
  where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version;

  v_raw_band:=case when v_index_score>=85 then 'flourishing' when v_index_score>=70 then 'resilient' when v_index_score>=55 then 'watch' when v_index_score>=40 then 'intervention' else 'critical' end;
  v_governed_band:=v_raw_band;
  if v_lowest_score<40 then
    v_flags:=v_flags||jsonb_build_array('DIMENSION_THRESHOLD_BREACH');
    if v_governed_band in ('flourishing','resilient','watch') then v_governed_band:='intervention'; end if;
  end if;
  if v_critical_human_count>=2 then v_flags:=v_flags||jsonb_build_array('MANDATORY_EXECUTIVE_REVIEW'); end if;
  if v_pp>85 and v_cap<50 then
    v_flags:=v_flags||jsonb_build_array('UNSUSTAINABLE_PERFORMANCE');
    if v_governed_band in ('flourishing','resilient') then v_governed_band:='watch'; end if;
  end if;
  v_intervention:=(v_lowest_score<40 or v_index_score<55 or v_critical_human_count>=2 or (v_pp>85 and v_cap<50));

  insert into workforce_ecology.index_scores(organization_id,operating_unit_id,team_id,period_start,period_end,wei_score,band,raw_band,governed_band,lowest_dimension,lowest_dimension_score,intervention_flag,governance_flags,calculation_version)
  values(p_organization_id,p_operating_unit_id,p_team_id,p_period_start,p_period_end,v_index_score,v_governed_band,v_raw_band,v_governed_band,v_lowest_dimension,v_lowest_score,v_intervention,v_flags,p_calculation_version)
  returning index_score_id into v_index_id;

  insert into workforce_ecology.audit_events(event_type,organization_id,operating_unit_id,team_id,period_start,period_end,calculation_version,evidence_lineage_reference,human_approval_state,payload)
  values('WEI_SCORE_CALCULATED',p_organization_id,p_operating_unit_id,p_team_id,p_period_start,p_period_end,p_calculation_version,'workforce_ecology.measurement_observations','pending',jsonb_build_object('index_score_id',v_index_id,'wei_score',v_index_score,'raw_band',v_raw_band,'governed_band',v_governed_band,'lowest_dimension',v_lowest_dimension,'lowest_score',v_lowest_score,'intervention_flag',v_intervention,'governance_flags',v_flags));

  insert into workforce_ecology.audit_events(event_type,organization_id,operating_unit_id,team_id,period_start,period_end,calculation_version,evidence_lineage_reference,human_approval_state,payload)
  select 'WEI_DIMENSION_THRESHOLD_BREACHED',p_organization_id,p_operating_unit_id,p_team_id,p_period_start,p_period_end,p_calculation_version,'workforce_ecology.dimension_scores','pending',jsonb_build_object('dimension_code',ds.dimension_code,'score',ds.score_0_100,'threshold',40,'governance_override_applied',true)
  from workforce_ecology.dimension_scores ds where ds.organization_id=p_organization_id and ds.operating_unit_id is not distinct from p_operating_unit_id and ds.team_id is not distinct from p_team_id and ds.period_start=p_period_start and ds.period_end=p_period_end and ds.calculation_version=p_calculation_version and ds.score_0_100<40;

  return v_index_id;
end;
$function$;

revoke execute on function workforce_ecology.calculate_wei_v1(text,text,text,date,date,text) from public, anon, authenticated;
grant execute on function workforce_ecology.calculate_wei_v1(text,text,text,date,date,text) to service_role;
