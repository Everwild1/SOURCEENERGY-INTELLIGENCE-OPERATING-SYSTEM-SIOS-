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
        select 1
        from ecology.ssr_air_event_outbox prior
        where prior.event_id=e.id
          and prior.escalation_tier=p.escalation_tier-1
          and prior.acknowledgment_required
          and prior.acknowledged_at is null
          and prior.acknowledgment_due_at is not null
          and prior.acknowledgment_due_at<=now()
          and prior.delivery_status not in ('cancelled','acknowledged')
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
        'escalation_reason','previous escalation tier acknowledgment SLA expired without acknowledgment',
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
    'escalation_gate','prior_tier_acknowledgment_sla_expired',
    'external_delivery_performed',false,
    'official_warning_authority',false,
    'meteorological_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

drop view if exists ecology.ssr_air_event_escalation_due;
create view ecology.ssr_air_event_escalation_due as
select
  e.id as event_id,
  e.severity,
  e.lifecycle_status,
  e.provider_code,
  e.event_time,
  e.detected_at,
  p.id as routing_policy_id,
  p.policy_code,
  p.escalation_tier,
  p.escalation_delay,
  p.channel_code,
  p.route_target,
  e.detected_at+p.escalation_delay as policy_time_gate,
  prior.acknowledgment_due_at as prior_tier_acknowledgment_due_at,
  greatest(e.detected_at+p.escalation_delay,prior.acknowledgment_due_at) as escalation_due_at,
  false::boolean as official_warning_authority,
  false::boolean as meteorological_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_events e
join ecology.ssr_air_routing_policies p on ecology.ssr_air_policy_matches_event(e,p)
join ecology.ssr_air_event_outbox prior
  on prior.event_id=e.id
 and prior.escalation_tier=p.escalation_tier-1
 and prior.acknowledgment_required
 and prior.acknowledged_at is null
 and prior.acknowledgment_due_at is not null
 and prior.delivery_status not in ('cancelled','acknowledged')
where p.escalation_tier>1
  and e.lifecycle_status='detected'
  and now()>=e.detected_at+p.escalation_delay
  and now()>=prior.acknowledgment_due_at
  and not exists (
    select 1 from ecology.ssr_air_event_outbox o
    where o.event_id=e.id and o.routing_policy_id=p.id
  );

comment on view ecology.ssr_air_event_escalation_due is 'Escalation becomes due only after both the policy time gate and the immediately prior tier acknowledgment SLA have expired.';
