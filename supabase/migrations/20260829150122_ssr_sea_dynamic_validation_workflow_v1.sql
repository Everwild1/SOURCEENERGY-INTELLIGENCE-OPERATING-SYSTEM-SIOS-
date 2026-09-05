create table if not exists ecology.ssr_sea_provider_access_requirements (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null unique,
  supported_access_method text not null,
  runtime_requirement text not null,
  credential_requirement text,
  readiness_status text not null check(readiness_status in('ready','credentials_required','runtime_required','credentials_and_runtime_required','blocked','planned')),
  required_variables text[] not null default '{}'::text[],
  provider_metadata jsonb not null default '{}'::jsonb,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(external_action_authority=false),check(official_warning_authority=false),check(canonical_identity_authority=false)
);

create table if not exists ecology.ssr_sea_validation_jobs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  provider_code text not null,
  job_type text not null,
  job_status text not null default 'queued' check(job_status in('queued','blocked','running','completed','failed','cancelled')),
  priority text not null default 'high' check(priority in('low','normal','high','critical')),
  requested_at timestamptz not null default now(),
  due_at timestamptz,
  request_payload jsonb not null default '{}'::jsonb,
  result_summary jsonb not null default '{}'::jsonb,
  blocker_reason text,
  attempts integer not null default 0,
  last_error text,
  external_action_performed boolean not null default false,
  physical_impact_asserted boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id,provider_code,job_type),
  check(external_action_performed=false),check(physical_impact_asserted=false),check(official_warning_authority=false),check(canonical_identity_authority=false)
);

alter table ecology.ssr_sea_provider_access_requirements enable row level security;
alter table ecology.ssr_sea_validation_jobs enable row level security;
drop policy if exists ssr_sea_provider_access_requirements_service_role on ecology.ssr_sea_provider_access_requirements;
drop policy if exists ssr_sea_validation_jobs_service_role on ecology.ssr_sea_validation_jobs;
create policy ssr_sea_provider_access_requirements_service_role on ecology.ssr_sea_provider_access_requirements for all to service_role using(true) with check(true);
create policy ssr_sea_validation_jobs_service_role on ecology.ssr_sea_validation_jobs for all to service_role using(true) with check(true);
revoke all on ecology.ssr_sea_provider_access_requirements,ecology.ssr_sea_validation_jobs from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_sea_provider_access_requirements,ecology.ssr_sea_validation_jobs to service_role;

insert into ecology.ssr_sea_provider_access_requirements(
  provider_code,supported_access_method,runtime_requirement,credential_requirement,readiness_status,required_variables,provider_metadata
) values (
  'COP-MARINE','Copernicus Marine Toolbox v2+ subset/describe','External Python or CLI worker with copernicusmarine Toolbox v2+','Copernicus Marine username/email and password','credentials_and_runtime_required',
  array['uo','vo','thetao','so','zos'],
  jsonb_build_object('dataset_resolution_strategy','Use copernicusmarine describe at runtime, then subset the latest Global Ocean Physics analysis/forecast datasets for the event point/time/depth','legacy_opendap_supported',false,'edge_runtime_note','Supabase Deno Edge Functions do not provide the supported Python Toolbox runtime')
),(
  'NOAA-ERDDAP','Public ERDDAP griddap CSV','Supabase Edge Function or SQL HTTP client',null,'ready',
  array['u_current','v_current','analysed_sst'],
  jsonb_build_object('role','observational cross-validation only; latest data may not align with forecast event time')
)
on conflict(provider_code) do update set supported_access_method=excluded.supported_access_method,runtime_requirement=excluded.runtime_requirement,
 credential_requirement=excluded.credential_requirement,readiness_status=excluded.readiness_status,required_variables=excluded.required_variables,
 provider_metadata=excluded.provider_metadata,updated_at=now();

insert into ecology.ssr_sea_validation_jobs(
  event_id,exposure_candidate_id,provider_code,job_type,job_status,priority,due_at,request_payload,blocker_reason
)
select e.id,x.id,'COP-MARINE','EVENT_ALIGNED_POINT_FORECAST','blocked','critical',e.event_time-interval '2 hours',
 jsonb_build_object('event_time',e.event_time,'latitude',e.grid_latitude,'longitude',e.grid_longitude,
   'coordinates_selection_method','nearest','variables',jsonb_build_array('uo','vo','thetao','so','zos'),
   'depth_range_m',jsonb_build_array(0,10),'purpose','event-aligned marine-state validation; not physical-impact assertion'),
 'Copernicus Marine Toolbox v2+ worker runtime and account credentials are not yet connected.'
from ecology.ssr_air_events e
join ecology.ssr_air_event_exposure_candidates x on x.event_id=e.id and x.subject_name='Port of Kingston / Kingston Container Terminal'
where e.id='db232a8d-4d10-43ad-82af-53bc16d8c02c'
on conflict(event_id,exposure_candidate_id,provider_code,job_type) do update set job_status='blocked',priority='critical',due_at=excluded.due_at,
 request_payload=excluded.request_payload,blocker_reason=excluded.blocker_reason,updated_at=now();

insert into ecology.ssr_air_event_action_items(
 event_id,decision_id,action_code,action_title,assignee,action_status,priority,due_at,action_payload,created_by,
 official_warning_authority,meteorological_warning_authority,canonical_identity_authority
)
select e.id,null,'ACQUIRE_EVENT_ALIGNED_MARINE_STATE','Acquire event-aligned marine forecast/analysis for Port of Kingston',
 'SEA_DATA_INTEGRATION','open','critical',e.event_time-interval '2 hours',
 jsonb_build_object('provider','COP-MARINE','required_variables',jsonb_build_array('uo','vo','thetao','so','zos'),'depth_range_m',jsonb_build_array(0,10),
 'authority_boundary','internal validation only; no physical impact or official warning assertion'),
 'SOURCEENERGY_CROSS_DOMAIN_VALIDATOR',false,false,false
from ecology.ssr_air_events e where e.id='db232a8d-4d10-43ad-82af-53bc16d8c02c'
  and not exists(select 1 from ecology.ssr_air_event_action_items i where i.event_id=e.id and i.action_code='ACQUIRE_EVENT_ALIGNED_MARINE_STATE');

insert into ecology.ssr_air_event_action_items(
 event_id,decision_id,action_code,action_title,assignee,action_status,priority,due_at,action_payload,created_by,
 official_warning_authority,meteorological_warning_authority,canonical_identity_authority
)
select e.id,null,'RECONCILE_PORT_COASTLINE_DATUM','Reconcile Port coastline/grid/datum evidence before exposure classification',
 'SSR_GEOSPATIAL_GOVERNANCE','open','high',e.event_time,
 jsonb_build_object('srtm15plus_elevation_m_egm96',3,'gebco_nearest_cell_m_msl',-12,'difference_m',15,
 'requirement','Resolve shoreline grid, horizontal-cell, and vertical-reference differences; do not infer impact from source disagreement'),
 'SOURCEENERGY_CROSS_DOMAIN_VALIDATOR',false,false,false
from ecology.ssr_air_events e where e.id='db232a8d-4d10-43ad-82af-53bc16d8c02c'
  and not exists(select 1 from ecology.ssr_air_event_action_items i where i.event_id=e.id and i.action_code='RECONCILE_PORT_COASTLINE_DATUM');

update ecology.ssr_scientific_data_providers
set integration_status='toolbox_runtime_and_credentials_required',
    notes='Copernicus Marine programmatic access is governed through the Copernicus Marine Toolbox v2+; event-aligned point/depth subset ingestion requires an external Python/CLI worker plus Copernicus Marine account credentials. Legacy OPeNDAP/MOTU paths are not part of the production design.',
    updated_at=now(),canonical_z_authority=false
where provider_code='COP-MARINE';

create or replace view ecology.ssr_sea_validation_job_status as
select j.id job_id,j.event_id,j.exposure_candidate_id,x.subject_name,j.provider_code,j.job_type,j.job_status,j.priority,j.due_at,j.blocker_reason,
 r.supported_access_method,r.runtime_requirement,r.credential_requirement,r.readiness_status,
 j.attempts,j.last_error,j.created_at,j.updated_at,false::boolean physical_impact_asserted,false::boolean official_warning_authority,false::boolean canonical_identity_authority
from ecology.ssr_sea_validation_jobs j
join ecology.ssr_air_event_exposure_candidates x on x.id=j.exposure_candidate_id
left join ecology.ssr_sea_provider_access_requirements r on r.provider_code=j.provider_code;

comment on table ecology.ssr_sea_validation_jobs is 'Governed SEA validation work queue. Jobs acquire scientific context only and cannot assert physical impact, issue official warnings, or alter canonical SSR identity.';
