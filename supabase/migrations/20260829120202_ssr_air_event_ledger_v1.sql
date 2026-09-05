create table if not exists ecology.ssr_air_events (
  id uuid primary key default gen_random_uuid(),
  event_fingerprint text not null unique,
  event_type text not null check (event_type in ('AIR_CHANGE_EVENT','AIR_STATISTICAL_DEVIATION_EVENT','AIR_COMPOSITE_EVENT')),
  severity text not null check (severity in ('ELEVATED','HIGH')),
  lifecycle_status text not null default 'detected' check (lifecycle_status in ('detected','acknowledged','closed','dismissed')),
  provider_code text not null,
  dataset_name text not null,
  source_profile_id uuid not null references ecology.ssr_air_profiles(id) on delete restrict,
  detected_at timestamptz not null default now(),
  event_time timestamptz not null,
  previous_event_time timestamptz,
  interval_hours numeric,
  grid_latitude double precision not null check (grid_latitude between -90 and 90),
  grid_longitude double precision not null check (grid_longitude between -180 and 180),
  pressure_level_hpa numeric not null check (pressure_level_hpa > 0),
  candidate_ssr_z_index integer,
  signal_flags text[] not null default '{}'::text[],
  signal_snapshot jsonb not null default '{}'::jsonb,
  statistical_snapshot jsonb not null default '{}'::jsonb,
  governance_scope text not null default 'internal_environmental_intelligence',
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  acknowledged_at timestamptz,
  acknowledged_by text,
  closed_at timestamptz,
  closed_by text,
  lifecycle_notes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ssr_air_event_no_official_warning_authority check (official_warning_authority = false),
  constraint ssr_air_event_no_meteorological_warning_authority check (meteorological_warning_authority = false),
  constraint ssr_air_event_no_canonical_identity_authority check (canonical_identity_authority = false)
);

create index if not exists ix_ssr_air_events_open
  on ecology.ssr_air_events(lifecycle_status,severity,event_time desc);
create index if not exists ix_ssr_air_events_provider_time
  on ecology.ssr_air_events(provider_code,event_time desc,pressure_level_hpa);

alter table ecology.ssr_air_events enable row level security;
drop policy if exists ssr_air_events_service_role on ecology.ssr_air_events;
create policy ssr_air_events_service_role on ecology.ssr_air_events
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_events from anon, authenticated;
grant select,insert,update,delete on ecology.ssr_air_events to service_role;

create table if not exists ecology.ssr_air_event_audit (
  id bigserial primary key,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  audit_action text not null,
  previous_status text,
  new_status text,
  actor_role text not null default current_user,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_air_event_audit_event_time
  on ecology.ssr_air_event_audit(event_id,recorded_at desc);

alter table ecology.ssr_air_event_audit enable row level security;
drop policy if exists ssr_air_event_audit_service_role_select on ecology.ssr_air_event_audit;
create policy ssr_air_event_audit_service_role_select on ecology.ssr_air_event_audit
  for select to service_role using (true);
revoke all on ecology.ssr_air_event_audit from anon, authenticated;
grant select on ecology.ssr_air_event_audit to service_role;

create or replace function ecology.audit_ssr_air_event_change()
returns trigger
language plpgsql
security definer
set search_path = ecology, public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into ecology.ssr_air_event_audit(event_id,audit_action,previous_status,new_status,audit_payload)
    values(new.id,'created',null,new.lifecycle_status,
      jsonb_build_object('severity',new.severity,'event_type',new.event_type,'event_time',new.event_time,'signal_flags',new.signal_flags));
    return new;
  end if;

  if tg_op = 'UPDATE' then
    insert into ecology.ssr_air_event_audit(event_id,audit_action,previous_status,new_status,audit_payload)
    values(new.id,
      case when old.lifecycle_status is distinct from new.lifecycle_status then 'lifecycle_transition' else 'updated' end,
      old.lifecycle_status,new.lifecycle_status,
      jsonb_build_object(
        'old_severity',old.severity,
        'new_severity',new.severity,
        'old_acknowledged_at',old.acknowledged_at,
        'new_acknowledged_at',new.acknowledged_at,
        'old_closed_at',old.closed_at,
        'new_closed_at',new.closed_at));
    return new;
  end if;

  return new;
end $$;

drop trigger if exists trg_ssr_air_event_audit on ecology.ssr_air_events;
create trigger trg_ssr_air_event_audit
after insert or update on ecology.ssr_air_events
for each row execute function ecology.audit_ssr_air_event_change();

create or replace function ecology.block_ssr_air_event_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ssr_air_event_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_event_audit_mutation on ecology.ssr_air_event_audit;
create trigger trg_block_ssr_air_event_audit_mutation
before update or delete on ecology.ssr_air_event_audit
for each row execute function ecology.block_ssr_air_event_audit_mutation();

create or replace view ecology.ssr_air_event_candidates as
select
  md5(concat_ws('|',
    s.provider_code,
    s.dataset_name,
    s.profile_id::text,
    s.evidence_time::text,
    s.grid_latitude::text,
    s.grid_longitude::text,
    s.pressure_level_hpa::text,
    s.operational_intensity,
    array_to_string(s.signal_flags,','))) as event_fingerprint,
  case
    when s.signal_flags && array['RAPID_TEMPERATURE_CHANGE','RAPID_WIND_VECTOR_CHANGE','RAPID_HUMIDITY_CHANGE','VERTICAL_MOTION_CHANGE']::text[]
      and s.signal_flags && array['MULTIVARIATE_STATISTICAL_DEVIATION']::text[] then 'AIR_COMPOSITE_EVENT'
    when s.signal_flags && array['RAPID_TEMPERATURE_CHANGE','RAPID_WIND_VECTOR_CHANGE','RAPID_HUMIDITY_CHANGE','VERTICAL_MOTION_CHANGE']::text[] then 'AIR_CHANGE_EVENT'
    else 'AIR_STATISTICAL_DEVIATION_EVENT'
  end as event_type,
  s.operational_intensity as severity,
  s.profile_id,
  s.provider_code,
  s.dataset_name,
  s.evidence_time,
  s.previous_evidence_time,
  s.interval_hours,
  s.grid_latitude,
  s.grid_longitude,
  s.pressure_level_hpa,
  s.candidate_ssr_z_index,
  s.signal_flags,
  s.t,s.u,s.v,s.rh,s.h,s.omega,
  s.delta_t,s.delta_u,s.delta_v,s.delta_rh,s.delta_h,s.delta_omega,
  s.wind_vector_change_mps,
  s.temperature_change_k_per_hour,
  s.rh_change_per_hour,
  s.provider_height_change_m_per_hour,
  s.sample_count,
  s.z_t,s.z_rh,s.z_wind,s.z_omega,s.max_abs_z,
  s.statistical_classification,
  case
    when s.operational_intensity='HIGH' then 100
    when coalesce(cardinality(s.signal_flags),0) >= 2 then 75
    else 50
  end as materialization_priority,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_operational_change_signals s
where s.operational_intensity in ('HIGH','ELEVATED')
  and coalesce(cardinality(s.signal_flags),0) > 0;

create or replace function public.ssr_air_materialize_events(
  p_min_intensity text default 'HIGH',
  p_since timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ecology, pg_temp
as $$
declare
  v_eligible integer := 0;
  v_inserted integer := 0;
  v_ids uuid[] := '{}'::uuid[];
begin
  if p_min_intensity not in ('HIGH','ELEVATED') then
    raise exception 'p_min_intensity must be HIGH or ELEVATED';
  end if;

  select count(*) into v_eligible
  from ecology.ssr_air_event_candidates c
  where (p_since is null or c.evidence_time >= p_since)
    and (p_min_intensity='ELEVATED' or c.severity='HIGH');

  with inserted as (
    insert into ecology.ssr_air_events(
      event_fingerprint,event_type,severity,lifecycle_status,
      provider_code,dataset_name,source_profile_id,event_time,previous_event_time,interval_hours,
      grid_latitude,grid_longitude,pressure_level_hpa,candidate_ssr_z_index,signal_flags,
      signal_snapshot,statistical_snapshot,
      official_warning_authority,meteorological_warning_authority,canonical_identity_authority
    )
    select
      c.event_fingerprint,c.event_type,c.severity,'detected',
      c.provider_code,c.dataset_name,c.profile_id,c.evidence_time,c.previous_evidence_time,c.interval_hours,
      c.grid_latitude,c.grid_longitude,c.pressure_level_hpa,c.candidate_ssr_z_index,c.signal_flags,
      jsonb_build_object(
        'current_values',jsonb_build_object('t',c.t,'u',c.u,'v',c.v,'rh',c.rh,'h',c.h,'omega',c.omega),
        'deltas',jsonb_build_object('t',c.delta_t,'u',c.delta_u,'v',c.delta_v,'rh',c.delta_rh,'h',c.delta_h,'omega',c.delta_omega),
        'rates',jsonb_build_object('temperature_k_per_hour',c.temperature_change_k_per_hour,'rh_per_hour',c.rh_change_per_hour,'provider_height_m_per_hour',c.provider_height_change_m_per_hour),
        'wind_vector_change_mps',c.wind_vector_change_mps,
        'materialization_priority',c.materialization_priority,
        'identity_boundary','environmental operational intelligence only; never canonical SSR identity'
      ),
      jsonb_build_object(
        'sample_count',c.sample_count,
        'z_t',c.z_t,'z_rh',c.z_rh,'z_wind',c.z_wind,'z_omega',c.z_omega,
        'max_abs_z',c.max_abs_z,
        'classification',c.statistical_classification
      ),
      false,false,false
    from ecology.ssr_air_event_candidates c
    where (p_since is null or c.evidence_time >= p_since)
      and (p_min_intensity='ELEVATED' or c.severity='HIGH')
    on conflict(event_fingerprint) do nothing
    returning id
  )
  select count(*),coalesce(array_agg(id),'{}'::uuid[])
    into v_inserted,v_ids
  from inserted;

  return jsonb_build_object(
    'minimum_intensity',p_min_intensity,
    'eligible_count',v_eligible,
    'inserted_count',v_inserted,
    'existing_count',v_eligible-v_inserted,
    'event_ids',v_ids,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_air_materialize_events(text,timestamptz) from public,anon,authenticated;
grant execute on function public.ssr_air_materialize_events(text,timestamptz) to service_role;

create or replace function public.ssr_air_event_transition(
  p_event_id uuid,
  p_new_status text,
  p_actor text,
  p_note jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, ecology, pg_temp
as $$
declare
  v_old text;
  v_event ecology.ssr_air_events%rowtype;
begin
  if p_new_status not in ('acknowledged','closed','dismissed') then
    raise exception 'unsupported lifecycle status';
  end if;

  select lifecycle_status into v_old
  from ecology.ssr_air_events
  where id=p_event_id
  for update;

  if not found then raise exception 'event not found'; end if;

  if v_old in ('closed','dismissed') then
    raise exception 'terminal event cannot transition';
  end if;

  update ecology.ssr_air_events
  set lifecycle_status=p_new_status,
      acknowledged_at=case when p_new_status='acknowledged' then now() else acknowledged_at end,
      acknowledged_by=case when p_new_status='acknowledged' then p_actor else acknowledged_by end,
      closed_at=case when p_new_status in ('closed','dismissed') then now() else closed_at end,
      closed_by=case when p_new_status in ('closed','dismissed') then p_actor else closed_by end,
      lifecycle_notes=lifecycle_notes || jsonb_build_array(jsonb_build_object('at',now(),'actor',p_actor,'from',v_old,'to',p_new_status,'note',coalesce(p_note,'{}'::jsonb))),
      updated_at=now()
  where id=p_event_id
  returning * into v_event;

  return jsonb_build_object('event_id',v_event.id,'previous_status',v_old,'new_status',v_event.lifecycle_status,'updated_at',v_event.updated_at);
end $$;

revoke all on function public.ssr_air_event_transition(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_air_event_transition(uuid,text,text,jsonb) to service_role;

create or replace view ecology.ssr_air_open_events as
select *
from ecology.ssr_air_events
where lifecycle_status in ('detected','acknowledged')
order by case severity when 'HIGH' then 1 else 2 end,event_time desc,pressure_level_hpa desc;

create or replace view ecology.ssr_air_event_operational_status as
select
  provider_code,
  severity,
  lifecycle_status,
  count(*) as event_count,
  min(event_time) as earliest_event_time,
  max(event_time) as latest_event_time,
  bool_and(official_warning_authority=false) as official_warning_boundary_preserved,
  bool_and(meteorological_warning_authority=false) as meteorological_warning_boundary_preserved,
  bool_and(canonical_identity_authority=false) as identity_boundary_preserved
from ecology.ssr_air_events
group by provider_code,severity,lifecycle_status;

comment on table ecology.ssr_air_events is 'Auditable AIR environmental-intelligence event ledger. Events are internal analytical artifacts, not official meteorological warnings and never canonical SSR identity authority.';
comment on view ecology.ssr_air_event_candidates is 'Qualified AIR analytical candidates. Materialization does not confer official warning authority or canonical SSR authority.';
