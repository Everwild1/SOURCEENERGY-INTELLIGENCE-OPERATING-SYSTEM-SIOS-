create table if not exists ecology.ssr_air_event_decisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  decision_type text not null check (decision_type in ('ACKNOWLEDGE','CONTINUE_MONITORING','REQUEST_VALIDATION','CLOSE','DISMISS')),
  actor text not null,
  actor_role text not null default 'governance_reviewer',
  rationale jsonb not null default '{}'::jsonb,
  source_channel text not null default 'AIR_EVENT_COMMAND_CENTER',
  event_status_before text not null,
  event_status_after text not null,
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  constraint ssr_air_decision_actor_required check (length(trim(actor)) > 0),
  constraint ssr_air_decision_no_official_warning check (official_warning_authority=false),
  constraint ssr_air_decision_no_meteorological_warning check (meteorological_warning_authority=false),
  constraint ssr_air_decision_no_canonical_identity check (canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_event_decisions_event_time
  on ecology.ssr_air_event_decisions(event_id,created_at desc);

alter table ecology.ssr_air_event_decisions enable row level security;
drop policy if exists ssr_air_event_decisions_service_role_select on ecology.ssr_air_event_decisions;
create policy ssr_air_event_decisions_service_role_select on ecology.ssr_air_event_decisions
  for select to service_role using (true);
revoke all on ecology.ssr_air_event_decisions from anon,authenticated;
grant select on ecology.ssr_air_event_decisions to service_role;

create or replace function ecology.block_ssr_air_event_decision_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'ssr_air_event_decisions is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_event_decision_mutation on ecology.ssr_air_event_decisions;
create trigger trg_block_ssr_air_event_decision_mutation
before update or delete on ecology.ssr_air_event_decisions
for each row execute function ecology.block_ssr_air_event_decision_mutation();

create table if not exists ecology.ssr_air_event_action_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  decision_id uuid references ecology.ssr_air_event_decisions(id) on delete restrict,
  action_code text not null,
  action_title text not null,
  assignee text,
  action_status text not null default 'open' check (action_status in ('open','in_progress','completed','cancelled')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  due_at timestamptz,
  action_payload jsonb not null default '{}'::jsonb,
  completion_payload jsonb not null default '{}'::jsonb,
  created_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  completed_by text,
  official_warning_authority boolean not null default false,
  meteorological_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  constraint ssr_air_action_code_required check (length(trim(action_code)) > 0),
  constraint ssr_air_action_title_required check (length(trim(action_title)) > 0),
  constraint ssr_air_action_no_official_warning check (official_warning_authority=false),
  constraint ssr_air_action_no_meteorological_warning check (meteorological_warning_authority=false),
  constraint ssr_air_action_no_canonical_identity check (canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_event_action_items_queue
  on ecology.ssr_air_event_action_items(action_status,priority,due_at,created_at)
  where action_status in ('open','in_progress');
create index if not exists ix_ssr_air_event_action_items_event
  on ecology.ssr_air_event_action_items(event_id,created_at desc);

alter table ecology.ssr_air_event_action_items enable row level security;
drop policy if exists ssr_air_event_action_items_service_role on ecology.ssr_air_event_action_items;
create policy ssr_air_event_action_items_service_role on ecology.ssr_air_event_action_items
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_event_action_items from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_event_action_items to service_role;

create table if not exists ecology.ssr_air_event_action_audit (
  id bigserial primary key,
  action_item_id uuid not null references ecology.ssr_air_event_action_items(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  audit_action text not null,
  previous_status text,
  new_status text,
  actor text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_air_event_action_audit_item
  on ecology.ssr_air_event_action_audit(action_item_id,recorded_at desc);

alter table ecology.ssr_air_event_action_audit enable row level security;
drop policy if exists ssr_air_event_action_audit_service_role_select on ecology.ssr_air_event_action_audit;
create policy ssr_air_event_action_audit_service_role_select on ecology.ssr_air_event_action_audit
  for select to service_role using (true);
revoke all on ecology.ssr_air_event_action_audit from anon,authenticated;
grant select on ecology.ssr_air_event_action_audit to service_role;

create or replace function ecology.audit_ssr_air_event_action_change()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_air_event_action_audit(action_item_id,event_id,audit_action,previous_status,new_status,actor,audit_payload)
    values(new.id,new.event_id,'created',null,new.action_status,new.created_by,
      jsonb_build_object('action_code',new.action_code,'title',new.action_title,'priority',new.priority,'due_at',new.due_at,'assignee',new.assignee));
    return new;
  end if;
  if tg_op='UPDATE' then
    insert into ecology.ssr_air_event_action_audit(action_item_id,event_id,audit_action,previous_status,new_status,actor,audit_payload)
    values(new.id,new.event_id,
      case when old.action_status is distinct from new.action_status then 'status_transition' else 'updated' end,
      old.action_status,new.action_status,coalesce(new.completed_by,new.assignee),
      jsonb_build_object('old_due_at',old.due_at,'new_due_at',new.due_at,'completion_payload',new.completion_payload));
    return new;
  end if;
  return new;
end $$;

drop trigger if exists trg_ssr_air_event_action_audit on ecology.ssr_air_event_action_items;
create trigger trg_ssr_air_event_action_audit
after insert or update on ecology.ssr_air_event_action_items
for each row execute function ecology.audit_ssr_air_event_action_change();

create or replace function ecology.block_ssr_air_event_action_audit_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'ssr_air_event_action_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_event_action_audit_mutation on ecology.ssr_air_event_action_audit;
create trigger trg_block_ssr_air_event_action_audit_mutation
before update or delete on ecology.ssr_air_event_action_audit
for each row execute function ecology.block_ssr_air_event_action_audit_mutation();

create or replace view ecology.ssr_air_event_command_center as
select
  e.id as event_id,
  e.event_type,
  e.severity,
  e.lifecycle_status,
  e.provider_code,
  e.dataset_name,
  e.event_time,
  e.detected_at,
  e.grid_latitude,
  e.grid_longitude,
  e.pressure_level_hpa,
  e.candidate_ssr_z_index,
  e.signal_flags,
  coalesce(r.route_count,0) as route_count,
  coalesce(r.delivered_route_count,0) as delivered_route_count,
  coalesce(r.awaiting_acknowledgment_count,0) as awaiting_acknowledgment_count,
  coalesce(r.overdue_acknowledgment_count,0) as overdue_acknowledgment_count,
  r.next_acknowledgment_due_at,
  d.latest_decision_type,
  d.latest_decision_at,
  d.latest_decision_actor,
  coalesce(a.open_action_count,0) as open_action_count,
  coalesce(a.overdue_action_count,0) as overdue_action_count,
  case
    when e.lifecycle_status in ('closed','dismissed') then 'TERMINAL'
    when coalesce(r.overdue_acknowledgment_count,0)>0 then 'ACKNOWLEDGMENT_OVERDUE'
    when coalesce(r.awaiting_acknowledgment_count,0)>0 then 'AWAITING_ACKNOWLEDGMENT'
    when e.lifecycle_status='acknowledged' and coalesce(a.open_action_count,0)>0 then 'ACKNOWLEDGED_WITH_OPEN_ACTIONS'
    when e.lifecycle_status='acknowledged' then 'ACKNOWLEDGED'
    when d.latest_decision_type='CONTINUE_MONITORING' then 'UNDER_MONITORING'
    else 'DETECTED'
  end as case_state,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_events e
left join lateral (
  select
    count(*) as route_count,
    count(*) filter (where o.delivery_status in ('delivered','acknowledged')) as delivered_route_count,
    count(*) filter (where o.acknowledgment_required and o.acknowledged_at is null and o.delivery_status<>'cancelled') as awaiting_acknowledgment_count,
    count(*) filter (where o.acknowledgment_required and o.acknowledged_at is null and o.acknowledgment_due_at<now() and o.delivery_status<>'cancelled') as overdue_acknowledgment_count,
    min(o.acknowledgment_due_at) filter (where o.acknowledgment_required and o.acknowledged_at is null and o.delivery_status<>'cancelled') as next_acknowledgment_due_at
  from ecology.ssr_air_event_outbox o where o.event_id=e.id
) r on true
left join lateral (
  select
    x.decision_type as latest_decision_type,
    x.created_at as latest_decision_at,
    x.actor as latest_decision_actor
  from ecology.ssr_air_event_decisions x
  where x.event_id=e.id
  order by x.created_at desc
  limit 1
) d on true
left join lateral (
  select
    count(*) filter (where i.action_status in ('open','in_progress')) as open_action_count,
    count(*) filter (where i.action_status in ('open','in_progress') and i.due_at<now()) as overdue_action_count
  from ecology.ssr_air_event_action_items i where i.event_id=e.id
) a on true;

create or replace view ecology.ssr_air_event_action_queue as
select
  i.id as action_item_id,
  i.event_id,
  e.severity as event_severity,
  e.event_time,
  e.provider_code,
  e.pressure_level_hpa,
  i.action_code,
  i.action_title,
  i.assignee,
  i.action_status,
  i.priority,
  i.due_at,
  case when i.due_at is not null and i.due_at<now() and i.action_status in ('open','in_progress') then true else false end as overdue,
  i.created_by,
  i.created_at,
  i.updated_at,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_event_action_items i
join ecology.ssr_air_events e on e.id=i.event_id
where i.action_status in ('open','in_progress')
order by case i.priority when 'critical' then 1 when 'high' then 2 when 'normal' then 3 else 4 end,
         i.due_at nulls last,i.created_at;

create or replace function public.ssr_air_event_case(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_result jsonb;
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then
    raise exception 'event not found';
  end if;

  select jsonb_build_object(
    'event',(select to_jsonb(e) from ecology.ssr_air_events e where e.id=p_event_id),
    'command_center',(select to_jsonb(c) from ecology.ssr_air_event_command_center c where c.event_id=p_event_id),
    'routes',coalesce((select jsonb_agg(to_jsonb(o) order by o.escalation_tier,o.created_at) from ecology.ssr_air_event_outbox o where o.event_id=p_event_id),'[]'::jsonb),
    'delivery_receipts',coalesce((select jsonb_agg(to_jsonb(r) order by r.occurred_at) from ecology.ssr_air_event_delivery_receipts r where r.event_id=p_event_id),'[]'::jsonb),
    'event_audit',coalesce((select jsonb_agg(to_jsonb(a) order by a.recorded_at) from ecology.ssr_air_event_audit a where a.event_id=p_event_id),'[]'::jsonb),
    'decisions',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at) from ecology.ssr_air_event_decisions d where d.event_id=p_event_id),'[]'::jsonb),
    'action_items',coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at) from ecology.ssr_air_event_action_items i where i.event_id=p_event_id),'[]'::jsonb),
    'authority_boundary',jsonb_build_object('official_warning_authority',false,'meteorological_warning_authority',false,'canonical_identity_authority',false)
  ) into v_result;
  return v_result;
end $$;

create or replace function public.ssr_air_event_record_decision(
  p_event_id uuid,
  p_decision_type text,
  p_actor text,
  p_actor_role text default 'governance_reviewer',
  p_rationale jsonb default '{}'::jsonb,
  p_action_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_event ecology.ssr_air_events%rowtype;
  v_status_before text;
  v_status_after text;
  v_decision_id uuid;
  v_transition jsonb := '{}'::jsonb;
  v_action_count integer := 0;
  v_item jsonb;
begin
  if p_decision_type not in ('ACKNOWLEDGE','CONTINUE_MONITORING','REQUEST_VALIDATION','CLOSE','DISMISS') then
    raise exception 'unsupported decision type';
  end if;
  if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;
  if jsonb_typeof(coalesce(p_action_items,'[]'::jsonb))<>'array' then raise exception 'p_action_items must be a JSON array'; end if;

  select * into v_event from ecology.ssr_air_events where id=p_event_id for update;
  if not found then raise exception 'event not found'; end if;
  v_status_before:=v_event.lifecycle_status;

  if p_decision_type='ACKNOWLEDGE' then
    v_transition:=public.ssr_air_acknowledge_event_routes(p_event_id,p_actor,p_rationale);
  elsif p_decision_type='CLOSE' then
    v_transition:=public.ssr_air_event_transition(p_event_id,'closed',p_actor,p_rationale);
  elsif p_decision_type='DISMISS' then
    v_transition:=public.ssr_air_event_transition(p_event_id,'dismissed',p_actor,p_rationale);
  end if;

  select lifecycle_status into v_status_after from ecology.ssr_air_events where id=p_event_id;

  insert into ecology.ssr_air_event_decisions(
    event_id,decision_type,actor,actor_role,rationale,event_status_before,event_status_after,
    official_warning_authority,meteorological_warning_authority,canonical_identity_authority
  ) values (
    p_event_id,p_decision_type,p_actor,coalesce(nullif(trim(p_actor_role),''),'governance_reviewer'),coalesce(p_rationale,'{}'::jsonb),
    v_status_before,v_status_after,false,false,false
  ) returning id into v_decision_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_action_items,'[]'::jsonb))
  loop
    insert into ecology.ssr_air_event_action_items(
      event_id,decision_id,action_code,action_title,assignee,action_status,priority,due_at,action_payload,created_by,
      official_warning_authority,meteorological_warning_authority,canonical_identity_authority
    ) values (
      p_event_id,v_decision_id,
      coalesce(nullif(v_item->>'action_code',''),'FOLLOW_UP'),
      coalesce(nullif(v_item->>'action_title',''),'AIR event follow-up'),
      nullif(v_item->>'assignee',''),
      'open',
      case when v_item->>'priority' in ('low','normal','high','critical') then v_item->>'priority' else 'normal' end,
      nullif(v_item->>'due_at','')::timestamptz,
      coalesce(v_item->'action_payload','{}'::jsonb),
      p_actor,false,false,false
    );
    v_action_count:=v_action_count+1;
  end loop;

  return jsonb_build_object(
    'decision_id',v_decision_id,
    'event_id',p_event_id,
    'decision_type',p_decision_type,
    'event_status_before',v_status_before,
    'event_status_after',v_status_after,
    'transition',v_transition,
    'action_items_created',v_action_count,
    'case',public.ssr_air_event_case(p_event_id),
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_air_event_action_transition(
  p_action_item_id uuid,
  p_new_status text,
  p_actor text,
  p_note jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_old text;
  v_item ecology.ssr_air_event_action_items%rowtype;
begin
  if p_new_status not in ('in_progress','completed','cancelled') then raise exception 'unsupported action status'; end if;
  if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;

  select action_status into v_old from ecology.ssr_air_event_action_items where id=p_action_item_id for update;
  if not found then raise exception 'action item not found'; end if;
  if v_old in ('completed','cancelled') then raise exception 'terminal action item cannot transition'; end if;

  update ecology.ssr_air_event_action_items
  set action_status=p_new_status,
      completion_payload=case when p_new_status in ('completed','cancelled') then coalesce(p_note,'{}'::jsonb) else completion_payload end,
      completed_at=case when p_new_status in ('completed','cancelled') then now() else completed_at end,
      completed_by=case when p_new_status in ('completed','cancelled') then p_actor else completed_by end,
      updated_at=now()
  where id=p_action_item_id
  returning * into v_item;

  return jsonb_build_object('action_item_id',v_item.id,'event_id',v_item.event_id,'previous_status',v_old,'new_status',v_item.action_status,'updated_at',v_item.updated_at);
end $$;

create or replace function public.ssr_air_event_command_center_overview()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
begin
  return jsonb_build_object(
    'generated_at',now(),
    'case_counts',coalesce((select jsonb_agg(to_jsonb(x)) from (
      select severity,lifecycle_status,case_state,count(*) as case_count
      from ecology.ssr_air_event_command_center
      group by severity,lifecycle_status,case_state
      order by severity,lifecycle_status,case_state
    ) x),'[]'::jsonb),
    'open_cases',coalesce((select jsonb_agg(to_jsonb(c) order by case c.severity when 'HIGH' then 1 else 2 end,c.event_time desc)
      from ecology.ssr_air_event_command_center c where c.lifecycle_status in ('detected','acknowledged')),'[]'::jsonb),
    'action_queue',coalesce((select jsonb_agg(to_jsonb(q)) from ecology.ssr_air_event_action_queue q),'[]'::jsonb),
    'routing_maintenance',(select public.ssr_air_routing_maintenance()),
    'authority_boundary',jsonb_build_object('official_warning_authority',false,'meteorological_warning_authority',false,'canonical_identity_authority',false)
  );
end $$;

revoke all on function public.ssr_air_event_case(uuid) from public,anon,authenticated;
revoke all on function public.ssr_air_event_record_decision(uuid,text,text,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_air_event_action_transition(uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_air_event_command_center_overview() from public,anon,authenticated;
grant execute on function public.ssr_air_event_case(uuid) to service_role;
grant execute on function public.ssr_air_event_record_decision(uuid,text,text,text,jsonb,jsonb) to service_role;
grant execute on function public.ssr_air_event_action_transition(uuid,text,text,jsonb) to service_role;
grant execute on function public.ssr_air_event_command_center_overview() to service_role;

comment on table ecology.ssr_air_event_decisions is 'Append-only human governance decisions for AIR analytical events. Decisions do not confer official warning authority or canonical SSR authority.';
comment on view ecology.ssr_air_event_command_center is 'AIR event case-management control surface. Internal environmental intelligence only; not an official meteorological warning service.';
