create table if not exists ecology.ssr_air_routing_policies (
  id uuid primary key default gen_random_uuid(),
  policy_code text not null unique,
  policy_name text not null,
  enabled boolean not null default true,
  min_severity text not null check (min_severity in ('ELEVATED','HIGH')),
  event_types text[] not null default '{}'::text[],
  provider_codes text[] not null default '{}'::text[],
  signal_flags_any text[] not null default '{}'::text[],
  escalation_tier integer not null check (escalation_tier between 1 and 9),
  escalation_delay interval not null default interval '0 minutes' check (escalation_delay >= interval '0 minutes'),
  channel_code text not null,
  route_target text not null,
  message_class text not null default 'internal_environmental_advisory',
  acknowledgment_required boolean not null default true,
  acknowledgment_sla interval,
  max_delivery_attempts integer not null default 5 check (max_delivery_attempts between 1 and 20),
  delivery_backoff_seconds integer not null default 300 check (delivery_backoff_seconds between 0 and 86400),
  policy_metadata jsonb not null default '{}'::jsonb,
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ssr_air_routing_no_official_warning check (official_warning_authority=false),
  constraint ssr_air_routing_no_meteorological_warning check (meteorological_warning_authority=false),
  constraint ssr_air_routing_no_canonical_identity check (canonical_identity_authority=false),
  constraint ssr_air_routing_ack_sla check (not acknowledgment_required or acknowledgment_sla is not null)
);

alter table ecology.ssr_air_routing_policies enable row level security;
drop policy if exists ssr_air_routing_policies_service_role on ecology.ssr_air_routing_policies;
create policy ssr_air_routing_policies_service_role on ecology.ssr_air_routing_policies
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_routing_policies from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_routing_policies to service_role;

create table if not exists ecology.ssr_air_event_outbox (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  routing_policy_id uuid not null references ecology.ssr_air_routing_policies(id) on delete restrict,
  escalation_tier integer not null check (escalation_tier between 1 and 9),
  channel_code text not null,
  route_target text not null,
  message_class text not null,
  payload jsonb not null,
  delivery_status text not null default 'pending' check (delivery_status in ('pending','leased','sent','delivered','failed','cancelled','acknowledged')),
  available_at timestamptz not null default now(),
  leased_at timestamptz,
  leased_until timestamptz,
  lease_token uuid,
  leased_by text,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_delivery_attempts integer not null check (max_delivery_attempts between 1 and 20),
  delivery_backoff_seconds integer not null default 300 check (delivery_backoff_seconds between 0 and 86400),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  delivered_at timestamptz,
  last_error text,
  acknowledgment_required boolean not null default true,
  acknowledgment_due_at timestamptz,
  acknowledged_at timestamptz,
  acknowledged_by text,
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,routing_policy_id),
  constraint ssr_air_outbox_no_official_warning check (official_warning_authority=false),
  constraint ssr_air_outbox_no_meteorological_warning check (meteorological_warning_authority=false),
  constraint ssr_air_outbox_no_canonical_identity check (canonical_identity_authority=false),
  constraint ssr_air_outbox_ack_due check (not acknowledgment_required or acknowledgment_due_at is not null)
);

create index if not exists ix_ssr_air_event_outbox_pending
  on ecology.ssr_air_event_outbox(delivery_status,available_at,escalation_tier,created_at)
  where delivery_status in ('pending','failed');
create index if not exists ix_ssr_air_event_outbox_event
  on ecology.ssr_air_event_outbox(event_id,escalation_tier,created_at);
create index if not exists ix_ssr_air_event_outbox_ack_due
  on ecology.ssr_air_event_outbox(acknowledgment_due_at)
  where acknowledgment_required and acknowledged_at is null and delivery_status not in ('cancelled','acknowledged');

alter table ecology.ssr_air_event_outbox enable row level security;
drop policy if exists ssr_air_event_outbox_service_role on ecology.ssr_air_event_outbox;
create policy ssr_air_event_outbox_service_role on ecology.ssr_air_event_outbox
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_event_outbox from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_event_outbox to service_role;

create table if not exists ecology.ssr_air_event_delivery_receipts (
  id bigserial primary key,
  outbox_id uuid not null references ecology.ssr_air_event_outbox(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  attempt_number integer not null default 0 check (attempt_number >= 0),
  receipt_state text not null check (receipt_state in ('queued','leased','sent','delivered','failed','cancelled','acknowledged')),
  channel_code text not null,
  route_target text not null,
  worker_id text,
  provider_message_id text,
  response_code text,
  response_payload jsonb not null default '{}'::jsonb,
  error_detail text,
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  occurred_at timestamptz not null default now(),
  constraint ssr_air_receipt_no_official_warning check (official_warning_authority=false),
  constraint ssr_air_receipt_no_meteorological_warning check (meteorological_warning_authority=false),
  constraint ssr_air_receipt_no_canonical_identity check (canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_delivery_receipts_outbox
  on ecology.ssr_air_event_delivery_receipts(outbox_id,occurred_at desc);

alter table ecology.ssr_air_event_delivery_receipts enable row level security;
drop policy if exists ssr_air_delivery_receipts_service_role_select on ecology.ssr_air_event_delivery_receipts;
create policy ssr_air_delivery_receipts_service_role_select on ecology.ssr_air_event_delivery_receipts
  for select to service_role using (true);
revoke all on ecology.ssr_air_event_delivery_receipts from anon,authenticated;
grant select on ecology.ssr_air_event_delivery_receipts to service_role;

create or replace function ecology.block_ssr_air_delivery_receipt_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'ssr_air_event_delivery_receipts is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_delivery_receipt_mutation on ecology.ssr_air_event_delivery_receipts;
create trigger trg_block_ssr_air_delivery_receipt_mutation
before update or delete on ecology.ssr_air_event_delivery_receipts
for each row execute function ecology.block_ssr_air_delivery_receipt_mutation();

create or replace function ecology.audit_ssr_air_outbox_insert()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  insert into ecology.ssr_air_event_delivery_receipts(
    outbox_id,event_id,attempt_number,receipt_state,channel_code,route_target,response_payload
  ) values (
    new.id,new.event_id,0,'queued',new.channel_code,new.route_target,
    jsonb_build_object('escalation_tier',new.escalation_tier,'message_class',new.message_class)
  );
  return new;
end $$;

drop trigger if exists trg_ssr_air_outbox_queued_receipt on ecology.ssr_air_event_outbox;
create trigger trg_ssr_air_outbox_queued_receipt
after insert on ecology.ssr_air_event_outbox
for each row execute function ecology.audit_ssr_air_outbox_insert();

insert into ecology.ssr_air_routing_policies(
  policy_code,policy_name,min_severity,event_types,provider_codes,signal_flags_any,
  escalation_tier,escalation_delay,channel_code,route_target,message_class,
  acknowledgment_required,acknowledgment_sla,max_delivery_attempts,delivery_backoff_seconds,policy_metadata
) values
(
  'AIR_HIGH_T1_GOVERNANCE_REVIEW','High AIR event — primary governance review','HIGH','{}','{}','{}',
  1,interval '0 minutes','INTERNAL_QUEUE','AIR_GOVERNANCE_REVIEW','internal_environmental_advisory',
  true,interval '1 hour',5,300,jsonb_build_object('routing_scope','primary_internal_review','external_delivery_enabled',false)
),
(
  'AIR_HIGH_T2_ARCHITECT_ESCALATION','High AIR event — architect escalation','HIGH','{}','{}','{}',
  2,interval '1 hour','INTERNAL_QUEUE','ARCHITECT_EXECUTIVE_REVIEW','internal_environmental_escalation',
  true,interval '2 hours',5,600,jsonb_build_object('routing_scope','unacknowledged_high_event_escalation','external_delivery_enabled',false)
),
(
  'AIR_HIGH_T3_RESILIENCE_COORDINATION','High AIR event — resilience coordination','HIGH','{}','{}','{}',
  3,interval '4 hours','INTERNAL_QUEUE','RESILIENCE_COORDINATION_REVIEW','internal_environmental_escalation',
  true,interval '4 hours',5,900,jsonb_build_object('routing_scope','sustained_unacknowledged_high_event','external_delivery_enabled',false)
),
(
  'AIR_ELEVATED_T1_ANALYST_REVIEW','Elevated AIR event — analyst review','ELEVATED','{}','{}','{}',
  1,interval '0 minutes','INTERNAL_QUEUE','AIR_ANALYST_REVIEW','internal_environmental_observation',
  false,null,3,600,jsonb_build_object('routing_scope','elevated_internal_review','external_delivery_enabled',false)
)
on conflict(policy_code) do update set
  policy_name=excluded.policy_name,
  enabled=true,
  min_severity=excluded.min_severity,
  event_types=excluded.event_types,
  provider_codes=excluded.provider_codes,
  signal_flags_any=excluded.signal_flags_any,
  escalation_tier=excluded.escalation_tier,
  escalation_delay=excluded.escalation_delay,
  channel_code=excluded.channel_code,
  route_target=excluded.route_target,
  message_class=excluded.message_class,
  acknowledgment_required=excluded.acknowledgment_required,
  acknowledgment_sla=excluded.acknowledgment_sla,
  max_delivery_attempts=excluded.max_delivery_attempts,
  delivery_backoff_seconds=excluded.delivery_backoff_seconds,
  policy_metadata=excluded.policy_metadata,
  official_warning_authority=false,
  meteorological_warning_authority=false,
  canonical_identity_authority=false,
  updated_at=now();

create or replace function ecology.ssr_air_policy_matches_event(
  p_event ecology.ssr_air_events,
  p_policy ecology.ssr_air_routing_policies
)
returns boolean
language sql
stable
as $$
  select
    p_policy.enabled
    and (p_policy.min_severity='ELEVATED' or p_event.severity='HIGH')
    and (cardinality(p_policy.event_types)=0 or p_event.event_type=any(p_policy.event_types))
    and (cardinality(p_policy.provider_codes)=0 or p_event.provider_code=any(p_policy.provider_codes))
    and (cardinality(p_policy.signal_flags_any)=0 or p_event.signal_flags && p_policy.signal_flags_any)
$$;

create or replace function ecology.ssr_air_route_event_internal(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_event ecology.ssr_air_events%rowtype;
  v_inserted integer := 0;
  v_ids uuid[] := '{}'::uuid[];
begin
  select * into v_event from ecology.ssr_air_events where id=p_event_id;
  if not found then raise exception 'event not found'; end if;

  with inserted as (
    insert into ecology.ssr_air_event_outbox(
      event_id,routing_policy_id,escalation_tier,channel_code,route_target,message_class,payload,
      delivery_status,available_at,max_delivery_attempts,delivery_backoff_seconds,
      acknowledgment_required,acknowledgment_due_at,
      official_warning_authority,meteorological_warning_authority,canonical_identity_authority
    )
    select
      v_event.id,p.id,p.escalation_tier,p.channel_code,p.route_target,p.message_class,
      jsonb_build_object(
        'event_id',v_event.id,
        'event_type',v_event.event_type,
        'severity',v_event.severity,
        'lifecycle_status',v_event.lifecycle_status,
        'provider_code',v_event.provider_code,
        'dataset_name',v_event.dataset_name,
        'event_time',v_event.event_time,
        'previous_event_time',v_event.previous_event_time,
        'grid',jsonb_build_object('latitude',v_event.grid_latitude,'longitude',v_event.grid_longitude),
        'pressure_level_hpa',v_event.pressure_level_hpa,
        'candidate_ssr_z_index',v_event.candidate_ssr_z_index,
        'signal_flags',v_event.signal_flags,
        'governance_scope',v_event.governance_scope,
        'authority_boundary',jsonb_build_object(
          'official_warning_authority',false,
          'meteorological_warning_authority',false,
          'canonical_identity_authority',false),
        'routing_policy',p.policy_code
      ),
      'pending',greatest(now(),v_event.detected_at+p.escalation_delay),p.max_delivery_attempts,p.delivery_backoff_seconds,
      p.acknowledgment_required,
      case when p.acknowledgment_required then greatest(now(),v_event.detected_at+p.escalation_delay)+p.acknowledgment_sla else null end,
      false,false,false
    from ecology.ssr_air_routing_policies p
    where p.escalation_tier=1
      and ecology.ssr_air_policy_matches_event(v_event,p)
    on conflict(event_id,routing_policy_id) do nothing
    returning id
  )
  select count(*),coalesce(array_agg(id),'{}'::uuid[]) into v_inserted,v_ids from inserted;

  return jsonb_build_object(
    'event_id',p_event_id,
    'inserted_count',v_inserted,
    'outbox_ids',v_ids,
    'external_delivery_performed',false,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function ecology.ssr_air_auto_route_event()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  perform ecology.ssr_air_route_event_internal(new.id);
  return new;
end $$;

drop trigger if exists trg_ssr_air_event_auto_route on ecology.ssr_air_events;
create trigger trg_ssr_air_event_auto_route
after insert on ecology.ssr_air_events
for each row execute function ecology.ssr_air_auto_route_event();

create or replace function ecology.ssr_air_escalate_due_routes_internal()
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_inserted integer := 0;
  v_ids uuid[] := '{}'::uuid[];
begin
  with eligible as (
    select e.*,p.id as policy_id,p.escalation_tier,p.channel_code,p.route_target,p.message_class,
           p.max_delivery_attempts,p.delivery_backoff_seconds,p.acknowledgment_required,p.acknowledgment_sla,p.policy_code
    from ecology.ssr_air_events e
    join ecology.ssr_air_routing_policies p on ecology.ssr_air_policy_matches_event(e,p)
    where p.escalation_tier>1
      and e.lifecycle_status='detected'
      and now() >= e.detected_at+p.escalation_delay
      and exists (
        select 1 from ecology.ssr_air_event_outbox o
        where o.event_id=e.id and o.escalation_tier=1 and o.acknowledgment_required and o.acknowledged_at is null
      )
  ), inserted as (
    insert into ecology.ssr_air_event_outbox(
      event_id,routing_policy_id,escalation_tier,channel_code,route_target,message_class,payload,
      delivery_status,available_at,max_delivery_attempts,delivery_backoff_seconds,
      acknowledgment_required,acknowledgment_due_at,
      official_warning_authority,meteorological_warning_authority,canonical_identity_authority
    )
    select
      e.id,e.policy_id,e.escalation_tier,e.channel_code,e.route_target,e.message_class,
      jsonb_build_object(
        'event_id',e.id,'event_type',e.event_type,'severity',e.severity,
        'event_time',e.event_time,'provider_code',e.provider_code,'pressure_level_hpa',e.pressure_level_hpa,
        'signal_flags',e.signal_flags,'routing_policy',e.policy_code,'escalation_tier',e.escalation_tier,
        'escalation_reason','required acknowledgment not recorded within governed escalation interval',
        'authority_boundary',jsonb_build_object('official_warning_authority',false,'meteorological_warning_authority',false,'canonical_identity_authority',false)
      ),
      'pending',now(),e.max_delivery_attempts,e.delivery_backoff_seconds,
      e.acknowledgment_required,
      case when e.acknowledgment_required then now()+e.acknowledgment_sla else null end,
      false,false,false
    from eligible e
    on conflict(event_id,routing_policy_id) do nothing
    returning id
  )
  select count(*),coalesce(array_agg(id),'{}'::uuid[]) into v_inserted,v_ids from inserted;

  return jsonb_build_object(
    'inserted_count',v_inserted,
    'outbox_ids',v_ids,
    'external_delivery_performed',false,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_air_route_event(p_event_id uuid)
returns jsonb
language sql
security definer
set search_path=public,ecology,pg_temp
as $$ select ecology.ssr_air_route_event_internal(p_event_id) $$;

create or replace function public.ssr_air_escalate_due_routes()
returns jsonb
language sql
security definer
set search_path=public,ecology,pg_temp
as $$ select ecology.ssr_air_escalate_due_routes_internal() $$;

create or replace function public.ssr_air_outbox_claim(
  p_worker_id text,
  p_limit integer default 10,
  p_lease_seconds integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_token uuid := gen_random_uuid();
  v_rows jsonb := '[]'::jsonb;
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_limit<1 or p_limit>100 then raise exception 'limit must be 1..100'; end if;
  if p_lease_seconds<30 or p_lease_seconds>3600 then raise exception 'lease seconds must be 30..3600'; end if;

  with picked as (
    select o.id
    from ecology.ssr_air_event_outbox o
    where o.delivery_status in ('pending','failed')
      and o.available_at<=now()
      and o.attempt_count<o.max_delivery_attempts
      and (o.leased_until is null or o.leased_until<now())
    order by o.escalation_tier desc,o.available_at,o.created_at
    for update skip locked
    limit p_limit
  ), updated as (
    update ecology.ssr_air_event_outbox o
    set delivery_status='leased',leased_at=now(),leased_until=now()+make_interval(secs=>p_lease_seconds),
        lease_token=v_token,leased_by=p_worker_id,attempt_count=o.attempt_count+1,last_attempt_at=now(),updated_at=now()
    from picked
    where o.id=picked.id
    returning o.*
  ), receipts as (
    insert into ecology.ssr_air_event_delivery_receipts(
      outbox_id,event_id,attempt_number,receipt_state,channel_code,route_target,worker_id,response_payload
    )
    select id,event_id,attempt_count,'leased',channel_code,route_target,p_worker_id,
           jsonb_build_object('lease_token',v_token,'leased_until',leased_until)
    from updated
    returning id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'outbox_id',u.id,'event_id',u.event_id,'lease_token',u.lease_token,'leased_until',u.leased_until,
    'attempt_number',u.attempt_count,'channel_code',u.channel_code,'route_target',u.route_target,
    'escalation_tier',u.escalation_tier,'message_class',u.message_class,'payload',u.payload
  )),'[]'::jsonb) into v_rows
  from updated u;

  return jsonb_build_object('worker_id',p_worker_id,'claimed_count',jsonb_array_length(v_rows),'items',v_rows);
end $$;

create or replace function public.ssr_air_outbox_record_delivery(
  p_outbox_id uuid,
  p_lease_token uuid,
  p_worker_id text,
  p_state text,
  p_provider_message_id text default null,
  p_response_code text default null,
  p_response_payload jsonb default '{}'::jsonb,
  p_error_detail text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_outbox ecology.ssr_air_event_outbox%rowtype;
  v_next_available timestamptz;
begin
  if p_state not in ('sent','delivered','failed','cancelled') then raise exception 'unsupported delivery state'; end if;

  select * into v_outbox from ecology.ssr_air_event_outbox where id=p_outbox_id for update;
  if not found then raise exception 'outbox record not found'; end if;
  if v_outbox.lease_token is distinct from p_lease_token or v_outbox.leased_by is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  v_next_available := case when p_state='failed'
    then now()+make_interval(secs=>v_outbox.delivery_backoff_seconds*greatest(1,v_outbox.attempt_count))
    else v_outbox.available_at end;

  update ecology.ssr_air_event_outbox
  set delivery_status=p_state,
      available_at=v_next_available,
      sent_at=case when p_state in ('sent','delivered') then coalesce(sent_at,now()) else sent_at end,
      delivered_at=case when p_state='delivered' then now() else delivered_at end,
      last_error=case when p_state='failed' then p_error_detail else null end,
      leased_until=null,lease_token=null,leased_by=null,updated_at=now()
  where id=p_outbox_id;

  insert into ecology.ssr_air_event_delivery_receipts(
    outbox_id,event_id,attempt_number,receipt_state,channel_code,route_target,worker_id,
    provider_message_id,response_code,response_payload,error_detail
  ) values (
    v_outbox.id,v_outbox.event_id,v_outbox.attempt_count,p_state,v_outbox.channel_code,v_outbox.route_target,p_worker_id,
    p_provider_message_id,p_response_code,coalesce(p_response_payload,'{}'::jsonb),p_error_detail
  );

  return jsonb_build_object(
    'outbox_id',p_outbox_id,'event_id',v_outbox.event_id,'delivery_status',p_state,
    'attempt_number',v_outbox.attempt_count,'next_available_at',v_next_available
  );
end $$;

create or replace function public.ssr_air_acknowledge_event_routes(
  p_event_id uuid,
  p_actor text,
  p_note jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_transition jsonb;
  v_count integer := 0;
begin
  v_transition := public.ssr_air_event_transition(p_event_id,'acknowledged',p_actor,p_note);

  with updated as (
    update ecology.ssr_air_event_outbox
    set delivery_status='acknowledged',acknowledged_at=now(),acknowledged_by=p_actor,
        leased_until=null,lease_token=null,leased_by=null,updated_at=now()
    where event_id=p_event_id
      and acknowledgment_required
      and acknowledged_at is null
      and delivery_status<>'cancelled'
    returning *
  ), receipts as (
    insert into ecology.ssr_air_event_delivery_receipts(
      outbox_id,event_id,attempt_number,receipt_state,channel_code,route_target,worker_id,response_payload
    )
    select id,event_id,attempt_count,'acknowledged',channel_code,route_target,p_actor,
           jsonb_build_object('note',coalesce(p_note,'{}'::jsonb))
    from updated
    returning id
  )
  select count(*) into v_count from updated;

  return jsonb_build_object('event_transition',v_transition,'acknowledged_route_count',v_count);
end $$;

revoke all on function public.ssr_air_route_event(uuid) from public,anon,authenticated;
revoke all on function public.ssr_air_escalate_due_routes() from public,anon,authenticated;
revoke all on function public.ssr_air_outbox_claim(text,integer,integer) from public,anon,authenticated;
revoke all on function public.ssr_air_outbox_record_delivery(uuid,uuid,text,text,text,text,jsonb,text) from public,anon,authenticated;
revoke all on function public.ssr_air_acknowledge_event_routes(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_air_route_event(uuid) to service_role;
grant execute on function public.ssr_air_escalate_due_routes() to service_role;
grant execute on function public.ssr_air_outbox_claim(text,integer,integer) to service_role;
grant execute on function public.ssr_air_outbox_record_delivery(uuid,uuid,text,text,text,text,jsonb,text) to service_role;
grant execute on function public.ssr_air_acknowledge_event_routes(uuid,text,jsonb) to service_role;

create or replace view ecology.ssr_air_event_escalation_due as
select
  e.id as event_id,e.severity,e.lifecycle_status,e.provider_code,e.event_time,e.detected_at,
  p.id as routing_policy_id,p.policy_code,p.escalation_tier,p.escalation_delay,p.channel_code,p.route_target,
  e.detected_at+p.escalation_delay as escalation_due_at,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_events e
join ecology.ssr_air_routing_policies p on ecology.ssr_air_policy_matches_event(e,p)
where p.escalation_tier>1
  and e.lifecycle_status='detected'
  and now()>=e.detected_at+p.escalation_delay
  and not exists (
    select 1 from ecology.ssr_air_event_outbox o
    where o.event_id=e.id and o.routing_policy_id=p.id
  )
  and exists (
    select 1 from ecology.ssr_air_event_outbox o
    where o.event_id=e.id and o.escalation_tier=1 and o.acknowledgment_required and o.acknowledged_at is null
  );

create or replace view ecology.ssr_air_event_outbox_pending as
select
  o.id as outbox_id,o.event_id,e.event_type,e.severity,e.lifecycle_status,e.event_time,
  o.escalation_tier,o.channel_code,o.route_target,o.message_class,o.delivery_status,
  o.available_at,o.attempt_count,o.max_delivery_attempts,o.acknowledgment_required,
  o.acknowledgment_due_at,o.acknowledged_at,o.created_at,
  false::boolean as external_delivery_confirmed,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_event_outbox o
join ecology.ssr_air_events e on e.id=o.event_id
where o.delivery_status in ('pending','leased','sent','failed');

create or replace view ecology.ssr_air_event_routing_operational_status as
select
  e.provider_code,e.severity,e.lifecycle_status,o.escalation_tier,o.delivery_status,
  count(*) as route_count,
  min(o.created_at) as earliest_route_created_at,
  max(o.created_at) as latest_route_created_at,
  count(*) filter (where o.acknowledgment_required and o.acknowledged_at is null) as awaiting_acknowledgment_count,
  bool_and(o.official_warning_authority=false) as official_warning_boundary_preserved,
  bool_and(o.meteorological_warning_authority=false) as meteorological_warning_boundary_preserved,
  bool_and(o.canonical_identity_authority=false) as identity_boundary_preserved
from ecology.ssr_air_event_outbox o
join ecology.ssr_air_events e on e.id=o.event_id
group by e.provider_code,e.severity,e.lifecycle_status,o.escalation_tier,o.delivery_status;

comment on table ecology.ssr_air_event_outbox is 'Channel-neutral internal routing outbox. It does not itself send external communications, issue official meteorological warnings, or alter canonical SSR identity.';
comment on table ecology.ssr_air_event_delivery_receipts is 'Append-only delivery-state evidence. A receipt records transport workflow only and never confers official warning or canonical identity authority.';
