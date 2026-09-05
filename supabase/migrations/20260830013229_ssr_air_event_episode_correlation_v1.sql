create table if not exists ecology.ssr_air_event_episodes (
  id uuid primary key default gen_random_uuid(),
  episode_key text not null unique,
  provider_code text not null,
  dataset_name text not null,
  grid_latitude double precision not null,
  grid_longitude double precision not null,
  pressure_level_hpa numeric not null,
  episode_start timestamptz not null,
  episode_end timestamptz not null,
  peak_severity text not null check (peak_severity in ('ELEVATED','HIGH')),
  episode_status text not null default 'active' check (episode_status in ('active','acknowledged','closed','dismissed')),
  governance_anchor_event_id uuid references ecology.ssr_air_events(id) on delete restrict,
  event_count integer not null default 0 check (event_count >= 0),
  signal_flags text[] not null default '{}'::text[],
  episode_summary jsonb not null default '{}'::jsonb,
  physical_impact_asserted boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (episode_end >= episode_start),
  check (physical_impact_asserted = false),
  check (official_warning_authority = false),
  check (canonical_identity_authority = false)
);

create table if not exists ecology.ssr_air_event_episode_members (
  episode_id uuid not null references ecology.ssr_air_event_episodes(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  sequence_number integer,
  temporal_gap_hours numeric,
  membership_reason text not null,
  joined_at timestamptz not null default now(),
  primary key (episode_id,event_id),
  unique (event_id)
);

create table if not exists ecology.ssr_air_event_episode_audit (
  id bigserial primary key,
  episode_id uuid not null references ecology.ssr_air_event_episodes(id) on delete restrict,
  audit_action text not null,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_air_event_episodes_time
  on ecology.ssr_air_event_episodes(provider_code,dataset_name,grid_latitude,grid_longitude,pressure_level_hpa,episode_start,episode_end);
create index if not exists ix_ssr_air_event_episode_members_event
  on ecology.ssr_air_event_episode_members(event_id);
create index if not exists ix_ssr_air_event_episode_audit_episode
  on ecology.ssr_air_event_episode_audit(episode_id,recorded_at desc);

alter table ecology.ssr_air_event_episodes enable row level security;
alter table ecology.ssr_air_event_episode_members enable row level security;
alter table ecology.ssr_air_event_episode_audit enable row level security;

drop policy if exists ssr_air_event_episodes_service_role on ecology.ssr_air_event_episodes;
drop policy if exists ssr_air_event_episode_members_service_role on ecology.ssr_air_event_episode_members;
drop policy if exists ssr_air_event_episode_audit_service_role_select on ecology.ssr_air_event_episode_audit;
create policy ssr_air_event_episodes_service_role on ecology.ssr_air_event_episodes
  for all to service_role using (true) with check (true);
create policy ssr_air_event_episode_members_service_role on ecology.ssr_air_event_episode_members
  for all to service_role using (true) with check (true);
create policy ssr_air_event_episode_audit_service_role_select on ecology.ssr_air_event_episode_audit
  for select to service_role using (true);
revoke all on ecology.ssr_air_event_episodes,ecology.ssr_air_event_episode_members,ecology.ssr_air_event_episode_audit from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_event_episodes,ecology.ssr_air_event_episode_members to service_role;
grant select on ecology.ssr_air_event_episode_audit to service_role;

create or replace function ecology.audit_ssr_air_event_episode()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  insert into ecology.ssr_air_event_episode_audit(episode_id,audit_action,audit_payload)
  values(
    new.id,
    case when tg_op='INSERT' then 'created' else 'refreshed' end,
    jsonb_build_object(
      'episode_start',new.episode_start,
      'episode_end',new.episode_end,
      'peak_severity',new.peak_severity,
      'episode_status',new.episode_status,
      'event_count',new.event_count,
      'governance_anchor_event_id',new.governance_anchor_event_id,
      'signal_flags',new.signal_flags
    )
  );
  return new;
end $$;

drop trigger if exists trg_audit_ssr_air_event_episode on ecology.ssr_air_event_episodes;
create trigger trg_audit_ssr_air_event_episode
after insert or update on ecology.ssr_air_event_episodes
for each row execute function ecology.audit_ssr_air_event_episode();

create or replace function ecology.block_ssr_air_event_episode_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'ssr_air_event_episode_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_event_episode_audit_mutation on ecology.ssr_air_event_episode_audit;
create trigger trg_block_ssr_air_event_episode_audit_mutation
before update or delete on ecology.ssr_air_event_episode_audit
for each row execute function ecology.block_ssr_air_event_episode_audit_mutation();

create or replace function public.ssr_air_refresh_event_episodes(
  p_since timestamptz default null,
  p_max_gap_hours numeric default 4
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_event ecology.ssr_air_events%rowtype;
  v_episode ecology.ssr_air_event_episodes%rowtype;
  v_episode_id uuid;
  v_existing_episode_id uuid;
  v_created integer := 0;
  v_linked integer := 0;
  v_refreshed integer := 0;
  v_episode_ids uuid[] := '{}'::uuid[];
begin
  if p_max_gap_hours <= 0 or p_max_gap_hours > 24 then
    raise exception 'p_max_gap_hours must be > 0 and <= 24';
  end if;

  for v_event in
    select e.*
    from ecology.ssr_air_events e
    where (p_since is null or e.event_time >= p_since)
      and e.lifecycle_status <> 'dismissed'
    order by e.provider_code,e.dataset_name,e.grid_latitude,e.grid_longitude,e.pressure_level_hpa,e.event_time,e.created_at
  loop
    select m.episode_id into v_existing_episode_id
    from ecology.ssr_air_event_episode_members m
    where m.event_id=v_event.id;

    if found then
      if not (v_existing_episode_id = any(v_episode_ids)) then
        v_episode_ids := array_append(v_episode_ids,v_existing_episode_id);
      end if;
      continue;
    end if;

    select ep.* into v_episode
    from ecology.ssr_air_event_episodes ep
    where ep.provider_code=v_event.provider_code
      and ep.dataset_name=v_event.dataset_name
      and abs(ep.grid_latitude-v_event.grid_latitude) < 0.000001
      and abs(ep.grid_longitude-v_event.grid_longitude) < 0.000001
      and ep.pressure_level_hpa=v_event.pressure_level_hpa
      and v_event.event_time between
          ep.episode_start-make_interval(secs=>(p_max_gap_hours*3600)::integer)
          and ep.episode_end+make_interval(secs=>(p_max_gap_hours*3600)::integer)
      and ep.episode_status in ('active','acknowledged')
    order by least(
      abs(extract(epoch from (v_event.event_time-ep.episode_start))),
      abs(extract(epoch from (v_event.event_time-ep.episode_end)))
    )
    limit 1
    for update;

    if not found then
      insert into ecology.ssr_air_event_episodes(
        episode_key,provider_code,dataset_name,grid_latitude,grid_longitude,pressure_level_hpa,
        episode_start,episode_end,peak_severity,episode_status,governance_anchor_event_id,event_count,
        signal_flags,episode_summary,physical_impact_asserted,official_warning_authority,canonical_identity_authority
      ) values (
        md5(concat_ws('|',v_event.event_fingerprint,v_event.provider_code,v_event.dataset_name,v_event.event_time::text)),
        v_event.provider_code,v_event.dataset_name,v_event.grid_latitude,v_event.grid_longitude,v_event.pressure_level_hpa,
        v_event.event_time,v_event.event_time,v_event.severity,
        case when v_event.lifecycle_status='acknowledged' then 'acknowledged' else 'active' end,
        v_event.id,0,'{}'::text[],
        jsonb_build_object(
          'correlation_method','same provider, dataset, grid point and pressure level within a bounded temporal gap',
          'maximum_gap_hours',p_max_gap_hours,
          'physical_impact_asserted',false,
          'official_warning_authority',false,
          'canonical_identity_authority',false
        ),
        false,false,false
      ) returning id into v_episode_id;
      v_created := v_created+1;
    else
      v_episode_id := v_episode.id;
    end if;

    insert into ecology.ssr_air_event_episode_members(episode_id,event_id,membership_reason)
    values(
      v_episode_id,
      v_event.id,
      'Same provider, dataset, grid point and pressure level within the governed temporal-gap threshold.'
    )
    on conflict(event_id) do nothing;
    if found then v_linked := v_linked+1; end if;

    if not (v_episode_id = any(v_episode_ids)) then
      v_episode_ids := array_append(v_episode_ids,v_episode_id);
    end if;
  end loop;

  foreach v_episode_id in array v_episode_ids
  loop
    with members as (
      select e.*,
             row_number() over(order by e.event_time,e.created_at)::integer as seq,
             extract(epoch from (e.event_time-lag(e.event_time) over(order by e.event_time,e.created_at)))/3600.0 as gap_hours
      from ecology.ssr_air_event_episode_members m
      join ecology.ssr_air_events e on e.id=m.event_id
      where m.episode_id=v_episode_id
    ), anchor as (
      select id
      from members
      order by
        case lifecycle_status when 'acknowledged' then 1 when 'detected' then 2 else 3 end,
        case severity when 'HIGH' then 1 else 2 end,
        event_time
      limit 1
    ), flags as (
      select coalesce(array_agg(distinct flag),'{}'::text[]) as signal_flags
      from members m
      cross join lateral unnest(m.signal_flags) as flag
    )
    update ecology.ssr_air_event_episodes ep
    set episode_start=(select min(event_time) from members),
        episode_end=(select max(event_time) from members),
        peak_severity=case when exists(select 1 from members where severity='HIGH') then 'HIGH' else 'ELEVATED' end,
        episode_status=case
          when exists(select 1 from members where lifecycle_status='acknowledged') then 'acknowledged'
          when (select bool_and(lifecycle_status='closed') from members) then 'closed'
          when (select bool_and(lifecycle_status='dismissed') from members) then 'dismissed'
          else 'active'
        end,
        governance_anchor_event_id=(select id from anchor),
        event_count=(select count(*) from members),
        signal_flags=(select signal_flags from flags),
        episode_summary=ep.episode_summary||jsonb_build_object(
          'maximum_gap_hours',p_max_gap_hours,
          'event_ids',(select jsonb_agg(id order by event_time) from members),
          'latest_refresh_at',now(),
          'physical_impact_asserted',false,
          'official_warning_authority',false,
          'canonical_identity_authority',false
        ),
        updated_at=now()
    where ep.id=v_episode_id;

    update ecology.ssr_air_event_episode_members m
    set sequence_number=x.seq,
        temporal_gap_hours=x.gap_hours
    from (
      select e.id as event_id,
             row_number() over(order by e.event_time,e.created_at)::integer as seq,
             extract(epoch from (e.event_time-lag(e.event_time) over(order by e.event_time,e.created_at)))/3600.0 as gap_hours
      from ecology.ssr_air_event_episode_members mm
      join ecology.ssr_air_events e on e.id=mm.event_id
      where mm.episode_id=v_episode_id
    ) x
    where m.episode_id=v_episode_id
      and m.event_id=x.event_id;

    v_refreshed := v_refreshed+1;
  end loop;

  return jsonb_build_object(
    'episodes_created',v_created,
    'events_linked',v_linked,
    'episodes_refreshed',v_refreshed,
    'episode_ids',v_episode_ids,
    'maximum_gap_hours',p_max_gap_hours,
    'physical_impact_asserted',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_air_refresh_event_episodes(timestamptz,numeric) from public,anon,authenticated;
grant execute on function public.ssr_air_refresh_event_episodes(timestamptz,numeric) to service_role;

create or replace view ecology.ssr_air_event_episode_status as
select
  ep.*,
  coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_id',e.id,
        'event_time',e.event_time,
        'severity',e.severity,
        'lifecycle_status',e.lifecycle_status,
        'signal_flags',e.signal_flags,
        'sequence_number',m.sequence_number,
        'temporal_gap_hours',m.temporal_gap_hours,
        'source_profile_id',e.source_profile_id
      ) order by m.sequence_number
    ) filter(where e.id is not null),
    '[]'::jsonb
  ) as member_events
from ecology.ssr_air_event_episodes ep
left join ecology.ssr_air_event_episode_members m on m.episode_id=ep.id
left join ecology.ssr_air_events e on e.id=m.event_id
group by ep.id;

comment on table ecology.ssr_air_event_episodes is 'Correlated AIR analytical episodes. Episode grouping supports governance continuity but does not assert physical impact, issue official warnings, or modify canonical SSR identity.';
