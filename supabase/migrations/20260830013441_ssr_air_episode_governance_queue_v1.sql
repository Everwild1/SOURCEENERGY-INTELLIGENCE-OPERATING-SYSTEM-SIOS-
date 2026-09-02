create or replace view ecology.ssr_air_episode_governance_queue as
with member_rollup as (
  select
    m.episode_id,
    count(*)::integer as member_event_count,
    count(*) filter(where e.lifecycle_status='detected')::integer as detected_event_count,
    count(*) filter(where e.lifecycle_status='acknowledged')::integer as acknowledged_event_count,
    count(*) filter(where e.lifecycle_status='closed')::integer as closed_event_count,
    count(*) filter(where e.lifecycle_status='dismissed')::integer as dismissed_event_count,
    min(e.event_time) as first_event_time,
    max(e.event_time) as last_event_time
  from ecology.ssr_air_event_episode_members m
  join ecology.ssr_air_events e on e.id=m.event_id
  group by m.episode_id
), route_rollup as (
  select
    m.episode_id,
    count(distinct o.id)::integer as route_count,
    count(distinct o.id) filter(where o.delivery_status in('delivered','acknowledged'))::integer as delivered_route_count,
    count(distinct o.id) filter(
      where o.acknowledgment_required
        and o.acknowledged_at is null
        and o.delivery_status<>'cancelled'
    )::integer as awaiting_acknowledgment_count,
    count(distinct o.id) filter(
      where o.acknowledgment_required
        and o.acknowledged_at is null
        and o.acknowledgment_due_at<now()
        and o.delivery_status<>'cancelled'
    )::integer as overdue_acknowledgment_count,
    min(o.acknowledgment_due_at) filter(
      where o.acknowledgment_required
        and o.acknowledged_at is null
        and o.delivery_status<>'cancelled'
    ) as next_acknowledgment_due_at
  from ecology.ssr_air_event_episode_members m
  left join ecology.ssr_air_event_outbox o on o.event_id=m.event_id
  group by m.episode_id
), fusion_rollup as (
  select
    m.episode_id,
    count(distinct a.id)::integer as fusion_assessment_count,
    count(distinct a.id) filter(where a.evidence_readiness='READY_FOR_GOVERNANCE_REVIEW')::integer as evidence_ready_assessment_count,
    count(distinct a.id) filter(where a.governance_review_status='accepted')::integer as accepted_assessment_count,
    count(distinct a.id) filter(where a.governance_review_status='pending')::integer as pending_assessment_count,
    count(distinct a.id) filter(where cardinality(a.missing_required_domains)>0)::integer as incomplete_assessment_count
  from ecology.ssr_air_event_episode_members m
  left join ecology.ssr_air_land_sea_fusion_assessments a on a.event_id=m.event_id
  group by m.episode_id
)
select
  ep.id as episode_id,
  ep.episode_key,
  ep.provider_code,
  ep.dataset_name,
  ep.grid_latitude,
  ep.grid_longitude,
  ep.pressure_level_hpa,
  ep.episode_start,
  ep.episode_end,
  ep.peak_severity,
  ep.episode_status,
  ep.governance_anchor_event_id,
  anchor.lifecycle_status as governance_anchor_status,
  anchor.event_time as governance_anchor_time,
  coalesce(m.member_event_count,0) as member_event_count,
  coalesce(m.detected_event_count,0) as detected_event_count,
  coalesce(m.acknowledged_event_count,0) as acknowledged_event_count,
  coalesce(m.closed_event_count,0) as closed_event_count,
  coalesce(m.dismissed_event_count,0) as dismissed_event_count,
  coalesce(r.route_count,0) as route_count,
  coalesce(r.delivered_route_count,0) as delivered_route_count,
  coalesce(r.awaiting_acknowledgment_count,0) as awaiting_acknowledgment_count,
  coalesce(r.overdue_acknowledgment_count,0) as overdue_acknowledgment_count,
  r.next_acknowledgment_due_at,
  coalesce(f.fusion_assessment_count,0) as fusion_assessment_count,
  coalesce(f.evidence_ready_assessment_count,0) as evidence_ready_assessment_count,
  coalesce(f.accepted_assessment_count,0) as accepted_assessment_count,
  coalesce(f.pending_assessment_count,0) as pending_assessment_count,
  coalesce(f.incomplete_assessment_count,0) as incomplete_assessment_count,
  case
    when coalesce(r.overdue_acknowledgment_count,0)>0 then 'EPISODE_ACKNOWLEDGMENT_OVERDUE'
    when coalesce(f.incomplete_assessment_count,0)>0 then 'EPISODE_EVIDENCE_INCOMPLETE'
    when coalesce(r.awaiting_acknowledgment_count,0)>0 or coalesce(f.pending_assessment_count,0)>0 then 'EPISODE_GOVERNANCE_REVIEW_REQUIRED'
    when ep.episode_status='acknowledged' then 'EPISODE_ACKNOWLEDGED'
    when ep.episode_status in('closed','dismissed') then 'EPISODE_TERMINAL'
    else 'EPISODE_ACTIVE'
  end as governance_state,
  true::boolean as human_review_required,
  false::boolean as physical_impact_asserted,
  false::boolean as external_action_authority,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority,
  ep.created_at,
  ep.updated_at
from ecology.ssr_air_event_episodes ep
join ecology.ssr_air_events anchor on anchor.id=ep.governance_anchor_event_id
left join member_rollup m on m.episode_id=ep.id
left join route_rollup r on r.episode_id=ep.id
left join fusion_rollup f on f.episode_id=ep.id;

create or replace function public.ssr_air_episode_case(p_episode_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_result jsonb;
begin
  if not exists(select 1 from ecology.ssr_air_event_episodes where id=p_episode_id) then
    raise exception 'episode not found';
  end if;

  select jsonb_build_object(
    'governance',(select to_jsonb(q) from ecology.ssr_air_episode_governance_queue q where q.episode_id=p_episode_id),
    'episode',(select to_jsonb(s) from ecology.ssr_air_event_episode_status s where s.id=p_episode_id),
    'member_events',coalesce((
      select jsonb_agg(public.ssr_air_event_case(m.event_id) order by m.sequence_number)
      from ecology.ssr_air_event_episode_members m
      where m.episode_id=p_episode_id
    ),'[]'::jsonb),
    'authority_boundary',jsonb_build_object(
      'physical_impact_asserted',false,
      'external_action_authority',false,
      'official_warning_authority',false,
      'canonical_identity_authority',false
    )
  ) into v_result;
  return v_result;
end $$;

revoke all on function public.ssr_air_episode_case(uuid) from public,anon,authenticated;
grant execute on function public.ssr_air_episode_case(uuid) to service_role;

comment on view ecology.ssr_air_episode_governance_queue is 'Episode-level AIR governance queue combining member lifecycle, internal routing and AIR-LAND-SEA fusion readiness. Episode status does not assert physical impact, issue official warnings, perform external actions, or change canonical SSR identity.';
