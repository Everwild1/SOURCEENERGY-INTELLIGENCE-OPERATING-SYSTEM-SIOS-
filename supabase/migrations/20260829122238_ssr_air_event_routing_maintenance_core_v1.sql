create or replace function ecology.ssr_air_route_unrouted_events_internal()
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_event_id uuid;
  v_result jsonb;
  v_events integer := 0;
  v_routes integer := 0;
begin
  for v_event_id in
    select e.id
    from ecology.ssr_air_events e
    where e.lifecycle_status='detected'
      and not exists (
        select 1 from ecology.ssr_air_event_outbox o
        where o.event_id=e.id and o.escalation_tier=1
      )
    order by e.detected_at
  loop
    v_result := ecology.ssr_air_route_event_internal(v_event_id);
    v_events := v_events + 1;
    v_routes := v_routes + coalesce((v_result->>'inserted_count')::integer,0);
  end loop;

  return jsonb_build_object(
    'events_examined',v_events,
    'routes_inserted',v_routes,
    'external_delivery_performed',false,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function ecology.ssr_air_recover_expired_leases_internal()
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_recovered integer := 0;
  v_exhausted integer := 0;
begin
  with expired as (
    select *
    from ecology.ssr_air_event_outbox
    where delivery_status='leased'
      and leased_until is not null
      and leased_until<now()
    for update skip locked
  ), updated as (
    update ecology.ssr_air_event_outbox o
    set delivery_status='failed',
        available_at=case
          when o.attempt_count>=o.max_delivery_attempts then o.available_at
          else now()+make_interval(secs=>o.delivery_backoff_seconds*greatest(1,o.attempt_count))
        end,
        leased_at=null,
        leased_until=null,
        lease_token=null,
        leased_by=null,
        last_error='lease expired before a delivery receipt was recorded',
        updated_at=now()
    from expired e
    where o.id=e.id
    returning o.*, (o.attempt_count>=o.max_delivery_attempts) as attempts_exhausted
  ), receipts as (
    insert into ecology.ssr_air_event_delivery_receipts(
      outbox_id,event_id,attempt_number,receipt_state,channel_code,route_target,worker_id,response_code,response_payload,error_detail
    )
    select id,event_id,attempt_count,'failed',channel_code,route_target,'ROUTING_MAINTENANCE','LEASE_EXPIRED',
           jsonb_build_object('attempts_exhausted',attempts_exhausted,'recovered_at',now()),
           'lease expired before a delivery receipt was recorded'
    from updated
    returning id
  )
  select count(*),count(*) filter (where attempts_exhausted)
    into v_recovered,v_exhausted
  from updated;

  return jsonb_build_object(
    'recovered_count',v_recovered,
    'attempts_exhausted_count',v_exhausted,
    'external_delivery_performed',false
  );
end $$;

create or replace function public.ssr_air_routing_maintenance()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_unrouted jsonb;
  v_recovered jsonb;
  v_escalated jsonb;
begin
  v_unrouted := ecology.ssr_air_route_unrouted_events_internal();
  v_recovered := ecology.ssr_air_recover_expired_leases_internal();
  v_escalated := ecology.ssr_air_escalate_due_routes_internal();

  return jsonb_build_object(
    'unrouted_event_recovery',v_unrouted,
    'expired_lease_recovery',v_recovered,
    'due_escalations',v_escalated,
    'executed_at',now(),
    'external_delivery_performed',false,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_air_routing_maintenance() from public,anon,authenticated;
grant execute on function public.ssr_air_routing_maintenance() to service_role;

create or replace view ecology.ssr_air_event_acknowledgment_overdue as
select
  o.id as outbox_id,
  o.event_id,
  e.event_type,
  e.severity,
  e.lifecycle_status,
  e.provider_code,
  e.event_time,
  o.escalation_tier,
  o.channel_code,
  o.route_target,
  o.delivery_status,
  o.acknowledgment_due_at,
  now()-o.acknowledgment_due_at as overdue_duration,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_event_outbox o
join ecology.ssr_air_events e on e.id=o.event_id
where o.acknowledgment_required
  and o.acknowledged_at is null
  and o.acknowledgment_due_at<now()
  and o.delivery_status not in ('cancelled','acknowledged')
  and e.lifecycle_status='detected';

create or replace view ecology.ssr_air_event_outbox_dead_letter as
select
  o.id as outbox_id,
  o.event_id,
  e.event_type,
  e.severity,
  e.provider_code,
  e.event_time,
  o.escalation_tier,
  o.channel_code,
  o.route_target,
  o.attempt_count,
  o.max_delivery_attempts,
  o.last_error,
  o.last_attempt_at,
  o.updated_at,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_event_outbox o
join ecology.ssr_air_events e on e.id=o.event_id
where o.delivery_status='failed'
  and o.attempt_count>=o.max_delivery_attempts;

create or replace view ecology.ssr_air_event_delivery_timeline as
select
  r.id as receipt_id,
  r.outbox_id,
  r.event_id,
  e.event_type,
  e.severity,
  e.provider_code,
  e.event_time,
  o.escalation_tier,
  r.attempt_number,
  r.receipt_state,
  r.channel_code,
  r.route_target,
  r.worker_id,
  r.provider_message_id,
  r.response_code,
  r.response_payload,
  r.error_detail,
  r.occurred_at,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_event_delivery_receipts r
join ecology.ssr_air_event_outbox o on o.id=r.outbox_id
join ecology.ssr_air_events e on e.id=r.event_id;

comment on function public.ssr_air_routing_maintenance() is 'Periodic internal maintenance: route unhandled events, recover expired leases, and materialize due escalation tiers. It performs no external delivery and confers no official warning or canonical identity authority.';
