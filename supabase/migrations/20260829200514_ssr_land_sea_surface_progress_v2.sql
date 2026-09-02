create or replace view ecology.ssr_land_sea_surface_progress as
with jm as (
  select
    count(*)::integer as total_anchors,
    count(*) filter(where elevation_m_egm96 is not null and z_index is not null)::integer as elevation_z_complete,
    count(*) filter(where canonical_address is not null)::integer as canonical_address_complete,
    count(*) filter(where promotion_eligible and canonicalization_status='promoted')::integer as promoted_complete
  from ecology.ssr_anchor_candidate_registry
  where jurisdiction_code='JM'
), sea_static as (
  select
    count(*) filter(where v.provider_code='OT-SRTM15PLUS' and v.validation_status='evidence_available')::integer as srtm15plus_ready,
    count(*) filter(where v.provider_code='GEBCO-SOURCE' and v.validation_status='evidence_available')::integer as gebco_ready,
    count(*) filter(where v.validation_type='COASTLINE_GRID_AND_DATUM_RECONCILIATION' and v.validation_status='validated')::integer as reconciliation_validated,
    count(*) filter(where v.validation_type='COASTLINE_GRID_AND_DATUM_RECONCILIATION' and v.validation_status='required')::integer as reconciliation_required
  from ecology.ssr_air_cross_domain_validations v
  join ecology.ssr_air_event_exposure_candidates x on x.id=v.exposure_candidate_id
  where x.subject_name ilike 'Port of Kingston%'
), noaa_context as (
  select
    bool_or(variables ? 'u_current_mps' and variables ? 'v_current_mps') as has_currents,
    bool_or(variables ? 'analysed_sst_c') as has_sst,
    count(distinct dataset_id)::integer as validated_datasets
  from ecology.ssr_sea_observations
  where provider_code='NOAA-ERDDAP' and quality_gate='PASS_SEA_OBSERVATIONAL_VALUE'
), rtofs as (
  select
    bool_or(variables ? 'u_velocity_mps' and variables ? 'v_velocity_mps'
      and retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT') as has_event_currents,
    bool_or(variables ? 'sea_surface_temperature_c'
      and retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT') as has_event_sst,
    bool_or(variables ? 'sea_surface_salinity_psu'
      and retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT') as has_event_salinity,
    bool_or(variables ? 'sea_surface_height_relative_to_geoid_m'
      and retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT') as has_event_ssh,
    count(*) filter(where retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT')::integer as aligned_observation_count
  from ecology.ssr_sea_observations
  where provider_code='NOAA-RTOFS'
    and quality_gate in ('PASS_NOAA_RTOFS_POINT_FORECAST','PASS_NOAA_RTOFS_SSHG_POINT_FORECAST')
), rtofs_jobs as (
  select
    count(*)::integer as total_jobs,
    count(*) filter(where job_status='completed' and result_quality_gate='PASS_NOAA_RTOFS_EVENT_ALIGNED_SURFACE_STATE')::integer as completed_full_state_jobs
  from ecology.ssr_sea_validation_jobs
  where provider_code='NOAA-RTOFS' and job_type='EVENT_ALIGNED_SURFACE_PROGNOSTIC'
), cop as (
  select
    count(*)::integer as total_jobs,
    count(*) filter(where job_status='completed')::integer as completed_jobs,
    count(*) filter(where job_status='blocked')::integer as blocked_jobs,
    max(blocker_reason) filter(where job_status='blocked') as blocker_reason
  from ecology.ssr_sea_validation_jobs
  where provider_code='COP-MARINE'
), computed as (
  select
    coalesce((select has_event_currents from rtofs),false)::integer
      + coalesce((select has_event_sst from rtofs),false)::integer
      + coalesce((select has_event_salinity from rtofs),false)::integer
      + coalesce((select has_event_ssh from rtofs),false)::integer as rtofs_variable_groups,
    coalesce((select has_currents from noaa_context),false)::integer
      + coalesce((select has_sst from noaa_context),false)::integer as context_variable_groups
)
select
  'LAND_POINT_ELEVATION_ENGINE'::text as component_code,
  'LAND'::text as domain,
  'Point elevation resolver and EGM96/Z quantization workflow'::text as scope,
  'OPERATIONAL'::text as progress_state,
  true as operational,
  true as complete_for_declared_scope,
  (select elevation_z_complete from jm) as completed_units,
  (select total_anchors from jm) as total_units,
  'Coverage completion is tracked separately from engine readiness.'::text as blocker,
  false::boolean as physical_impact_authority,
  true::boolean as canonical_z_authority,
  true::boolean as required_for_domain_completion
union all
select
  'LAND_JAMAICA_ANCHOR_COVERAGE','LAND','Current Jamaica reference-anchor canonicalization',
  case when jm.promoted_complete=jm.total_anchors and jm.total_anchors>0 then 'COMPLETE' else 'PARTIAL' end,
  true,
  jm.promoted_complete=jm.total_anchors and jm.total_anchors>0,
  jm.promoted_complete,jm.total_anchors,
  case when jm.promoted_complete=jm.total_anchors and jm.total_anchors>0 then null
    else 'Only fully promoted anchors count as complete; W3W, EGM96, source reconciliation, provenance/hash and promotion controls remain pending.' end,
  false,true,true
from jm
union all
select
  'LAND_EGM96_Z_COVERAGE','LAND','EGM96 elevation plus deterministic 3 m Z across current Jamaica anchors',
  case when jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0 then 'COMPLETE' else 'PARTIAL' end,
  true,
  jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0,
  jm.elevation_z_complete,jm.total_anchors,
  case when jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0 then null
    else 'Authoritative EGM96 elevation/Z remains missing for at least one current anchor.' end,
  false,true,true
from jm
union all
select
  'SEA_STATIC_PORT_POINT_GEOMETRY','SEA','Port of Kingston static coastal/seabed point evidence and grid/datum reconciliation',
  case
    when sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 and sea_static.reconciliation_validated>0 then 'COMPLETE_POINT_GEOMETRY_RECONCILED'
    when sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 then 'POINT_EVIDENCE_VALIDATED_RECONCILIATION_PENDING'
    else 'PARTIAL'
  end,
  sea_static.srtm15plus_ready>0 or sea_static.gebco_ready>0,
  sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 and sea_static.reconciliation_validated>0,
  least(sea_static.srtm15plus_ready,1)+least(sea_static.gebco_ready,1)+least(sea_static.reconciliation_validated,1),
  3,
  case
    when sea_static.reconciliation_validated>0 then null
    when sea_static.reconciliation_required>0 then 'SRTM15Plus EGM96 exact-point elevation and GEBCO MSL nearby-grid evidence require coastline/grid/datum reconciliation.'
    else 'Static point evidence or reconciliation remains incomplete.'
  end,
  false,false,true
from sea_static
union all
select
  'SEA_EVENT_ALIGNED_SURFACE_STATE','SEA','Port of Kingston event-aligned RTOFS currents, SST, salinity and sea-surface height relative to geoid',
  case
    when computed.rtofs_variable_groups=4 and rtofs_jobs.completed_full_state_jobs>0 then 'COMPLETE_EVENT_ALIGNED_SURFACE_STATE'
    when computed.rtofs_variable_groups>0 then 'PARTIAL_EVENT_ALIGNED_SURFACE_STATE'
    else 'NOT_STARTED'
  end,
  computed.rtofs_variable_groups>0,
  computed.rtofs_variable_groups=4 and rtofs_jobs.completed_full_state_jobs>0,
  computed.rtofs_variable_groups,
  4,
  case when computed.rtofs_variable_groups=4 and rtofs_jobs.completed_full_state_jobs>0 then null
    else 'One or more required event-aligned surface-state groups remain incomplete: currents, SST, salinity or sea-surface height.' end,
  false,false,true
from computed cross join rtofs_jobs
union all
select
  'SEA_OBSERVATIONAL_CONTEXT','SEA','NOAA independent observational context near Kingston: surface currents and SST',
  case when computed.context_variable_groups=2 then 'CONTEXT_VALIDATED' else 'PARTIAL_CONTEXT' end,
  computed.context_variable_groups>0,
  computed.context_variable_groups=2,
  computed.context_variable_groups,
  2,
  case when computed.context_variable_groups=2 then 'Context observations are not contemporaneous with the event and do not substitute for the event-aligned RTOFS state.'
    else 'Independent observational context remains incomplete.' end,
  false,false,false
from computed
union all
select
  'SEA_COPERNICUS_SECONDARY_VALIDATION','SEA','Optional independent Copernicus Marine event-aligned cross-validation',
  case
    when cop.total_jobs>0 and cop.completed_jobs=cop.total_jobs then 'COMPLETE_SECONDARY_VALIDATION'
    when cop.blocked_jobs>0 then 'BLOCKED_CREDENTIALS_AND_RUNTIME'
    else 'NOT_STARTED'
  end,
  cop.completed_jobs>0,
  cop.total_jobs>0 and cop.completed_jobs=cop.total_jobs,
  cop.completed_jobs,
  greatest(cop.total_jobs,1),
  coalesce(cop.blocker_reason,'Copernicus Marine Toolbox runtime and credentials are required for optional independent validation.'),
  false,false,false
from cop;

create or replace view ecology.ssr_land_sea_surface_summary as
select
  domain,
  count(*)::integer as component_count,
  count(*) filter(where operational)::integer as operational_components,
  count(*) filter(where complete_for_declared_scope)::integer as completed_components,
  coalesce(bool_and(complete_for_declared_scope) filter(where required_for_domain_completion),false) as domain_complete,
  case
    when coalesce(bool_and(complete_for_declared_scope) filter(where required_for_domain_completion),false)
      and count(*) filter(where not required_for_domain_completion and not complete_for_declared_scope)>0
      then 'COMPLETE_WITH_OPTIONAL_VALIDATION_OPEN'
    when coalesce(bool_and(complete_for_declared_scope) filter(where required_for_domain_completion),false)
      then 'COMPLETE'
    when bool_or(operational) then 'OPERATIONAL_WITH_OPEN_GATES'
    else 'BLOCKED_OR_NOT_STARTED'
  end as domain_state,
  array_agg(component_code order by component_code)
    filter(where required_for_domain_completion and not complete_for_declared_scope) as open_components,
  false::boolean as physical_impact_authority,
  false::boolean as official_warning_authority,
  count(*) filter(where required_for_domain_completion)::integer as required_component_count,
  count(*) filter(where required_for_domain_completion and complete_for_declared_scope)::integer as required_completed_components,
  array_agg(component_code order by component_code)
    filter(where not required_for_domain_completion and not complete_for_declared_scope) as open_optional_components
from ecology.ssr_land_sea_surface_progress
group by domain;

create table if not exists ecology.ssr_surface_closure_actions (
  id uuid primary key default gen_random_uuid(),
  action_code text not null unique,
  domain text not null check(domain in ('LAND','SEA')),
  component_code text not null,
  action_title text not null,
  action_status text not null check(action_status in ('open','in_progress','completed','blocked','cancelled')),
  priority text not null default 'normal' check(priority in ('low','normal','high','critical')),
  required_for_domain_completion boolean not null default true,
  blocker text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  physical_impact_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  check(physical_impact_authority=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

alter table ecology.ssr_surface_closure_actions enable row level security;
drop policy if exists ssr_surface_closure_actions_service_role on ecology.ssr_surface_closure_actions;
create policy ssr_surface_closure_actions_service_role on ecology.ssr_surface_closure_actions
  for all to service_role using(true) with check(true);
revoke all on ecology.ssr_surface_closure_actions from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_surface_closure_actions to service_role;

create or replace function public.ssr_refresh_surface_closure_actions()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_count integer;
begin
  insert into ecology.ssr_surface_closure_actions(
    action_code,domain,component_code,action_title,action_status,priority,
    required_for_domain_completion,blocker,evidence_snapshot,completed_at,
    physical_impact_authority,official_warning_authority,canonical_identity_authority
  )
  select
    p.component_code,p.domain,p.component_code,p.scope,
    case
      when p.complete_for_declared_scope then 'completed'
      when p.progress_state ilike 'BLOCKED%' then 'blocked'
      else 'open'
    end,
    case
      when p.required_for_domain_completion and not p.complete_for_declared_scope then 'critical'
      when not p.complete_for_declared_scope then 'normal'
      else 'low'
    end,
    p.required_for_domain_completion,p.blocker,
    jsonb_build_object(
      'progress_state',p.progress_state,'operational',p.operational,
      'completed_units',p.completed_units,'total_units',p.total_units,
      'complete_for_declared_scope',p.complete_for_declared_scope,
      'required_for_domain_completion',p.required_for_domain_completion,
      'refreshed_at',now()
    ),
    case when p.complete_for_declared_scope then now() else null end,
    false,false,false
  from ecology.ssr_land_sea_surface_progress p
  on conflict(action_code) do update set
    domain=excluded.domain,
    component_code=excluded.component_code,
    action_title=excluded.action_title,
    action_status=excluded.action_status,
    priority=excluded.priority,
    required_for_domain_completion=excluded.required_for_domain_completion,
    blocker=excluded.blocker,
    evidence_snapshot=excluded.evidence_snapshot,
    completed_at=case
      when excluded.action_status='completed' then coalesce(ecology.ssr_surface_closure_actions.completed_at,now())
      else null
    end,
    physical_impact_authority=false,
    official_warning_authority=false,
    canonical_identity_authority=false,
    updated_at=now();

  get diagnostics v_count=row_count;
  return jsonb_build_object(
    'refreshed_count',v_count,
    'land_state',(select domain_state from ecology.ssr_land_sea_surface_summary where domain='LAND'),
    'sea_state',(select domain_state from ecology.ssr_land_sea_surface_summary where domain='SEA'),
    'physical_impact_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_refresh_surface_closure_actions() from public,anon,authenticated;
grant execute on function public.ssr_refresh_surface_closure_actions() to service_role;

create or replace view ecology.ssr_surface_closure_dashboard as
select
  a.id,a.action_code,a.domain,a.component_code,a.action_title,a.action_status,a.priority,
  a.required_for_domain_completion,a.blocker,a.evidence_snapshot,a.completed_at,a.updated_at,
  p.progress_state,p.operational,p.complete_for_declared_scope,p.completed_units,p.total_units,
  false::boolean as physical_impact_authority,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_surface_closure_actions a
join ecology.ssr_land_sea_surface_progress p on p.component_code=a.component_code;

update ecology.ssr_air_cross_domain_validations
set evidence_snapshot=coalesce(evidence_snapshot,'{}'::jsonb)||jsonb_build_object(
      'validation_role','optional_independent_cross_validation',
      'blocking_primary_surface_scope',false,
      'primary_surface_state_provider','NOAA-RTOFS',
      'primary_surface_state_gate','PASS_NOAA_RTOFS_EVENT_ALIGNED_SURFACE_STATE',
      'progress_refreshed_at',now()
    ),
    review_conclusion=coalesce(review_conclusion,
      'Copernicus Marine remains an optional independent cross-validation path. Its credential/runtime blocker does not invalidate the completed NOAA RTOFS primary event-aligned surface-state evidence.'),
    updated_at=now()
where provider_code='COP-MARINE' and validation_type='MARINE_STATE_REVIEW';

comment on view ecology.ssr_land_sea_surface_progress is 'Evidence-based LAND/SEA surface progress. Required primary scope is separated from optional independent validation to prevent both false completion and false blocking.';
comment on view ecology.ssr_land_sea_surface_summary is 'Domain summary. domain_complete evaluates required components only; open_optional_components reports non-blocking independent validation.';
comment on table ecology.ssr_surface_closure_actions is 'Governed closure ledger synchronized from evidence-backed LAND/SEA progress. Completion does not assert physical impact, issue official warnings, or alter canonical identity outside governed source authority.';
