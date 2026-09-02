create index if not exists idx_wa_assessments_client_date on wealth_advisors.assessments(client_id, assessment_date desc);
create index if not exists idx_wa_roadmaps_client_updated on wealth_advisors.wealth_roadmaps(client_id, updated_at desc);
create index if not exists idx_wa_referrals_client_followup on wealth_advisors.referrals(client_id, follow_up_date, status);
create index if not exists idx_wa_capital_requests_client_updated on wealth_advisors.capital_requests(client_id, updated_at desc);
create index if not exists idx_wa_actions_roadmap_status_due on wealth_advisors.roadmap_actions(roadmap_id, status, due_date);

create or replace view public.wa_client_portal_overview
with (security_invoker = true)
as
select
  c.id as client_id,
  c.preferred_name,
  c.client_type,
  c.geographic_market,
  c.status as client_status,
  a.total_score as latest_fri_score,
  a.classification as latest_fri_classification,
  a.assessment_date as latest_assessment_date,
  wr.id as current_roadmap_id,
  wr.primary_pathway,
  wr.current_position,
  wr.target_position,
  wr.thirty_day_objective,
  wr.ninety_day_objective,
  wr.twelve_month_objective,
  wr.status as roadmap_status,
  coalesce(act.open_actions, 0) as open_actions,
  coalesce(doc.total_documents, 0) as total_documents,
  coalesce(doc.verified_documents, 0) as verified_documents,
  coalesce(cap.open_capital_requests, 0) as open_capital_requests,
  coalesce(cap.total_capital_requested, 0::numeric) as total_capital_requested,
  cap.currency as capital_currency,
  coalesce(ref.open_referrals, 0) as open_referrals,
  ref.next_follow_up_date,
  c.updated_at as client_updated_at
from wealth_advisors.clients c
left join lateral (
  select a1.total_score, a1.classification, a1.assessment_date
  from wealth_advisors.assessments a1
  where a1.client_id = c.id
  order by a1.assessment_date desc
  limit 1
) a on true
left join lateral (
  select w1.*
  from wealth_advisors.wealth_roadmaps w1
  where w1.client_id = c.id
  order by w1.updated_at desc
  limit 1
) wr on true
left join lateral (
  select count(*)::bigint as open_actions
  from wealth_advisors.roadmap_actions ra
  where ra.roadmap_id = wr.id
    and ra.status not in ('completed','cancelled')
) act on true
left join lateral (
  select
    count(*)::bigint as total_documents,
    count(*) filter (where d.evidence_status = 'verified')::bigint as verified_documents
  from wealth_advisors.documents d
  where d.client_id = c.id
) doc on true
left join lateral (
  select
    count(*) filter (where cr.readiness_status not in ('declined','closed','funded'))::bigint as open_capital_requests,
    sum(cr.amount_requested) as total_capital_requested,
    min(cr.currency)::text as currency
  from wealth_advisors.capital_requests cr
  where cr.client_id = c.id
) cap on true
left join lateral (
  select
    count(*) filter (where r.status not in ('closed','declined','cancelled'))::bigint as open_referrals,
    min(r.follow_up_date) filter (where r.status not in ('closed','declined','cancelled')) as next_follow_up_date
  from wealth_advisors.referrals r
  where r.client_id = c.id
) ref on true;

create or replace view public.wa_advisor_crm_queue
with (security_invoker = true)
as
select
  aa.advisor_user_id,
  c.id as client_id,
  c.legal_name,
  c.preferred_name,
  c.client_type,
  c.geographic_market,
  c.status as client_status,
  aa.assignment_role,
  aa.assigned_at,
  a.total_score as latest_fri_score,
  a.classification as latest_fri_classification,
  a.assessment_date as latest_assessment_date,
  wr.primary_pathway,
  wr.status as roadmap_status,
  coalesce(act.open_actions, 0) as open_actions,
  act.next_action_due_date,
  coalesce(cap.open_capital_requests, 0) as open_capital_requests,
  coalesce(cap.capital_requested, 0::numeric) as capital_requested,
  cap.currency as capital_currency,
  coalesce(ref.open_referrals, 0) as open_referrals,
  ref.next_follow_up_date,
  coalesce(comp.open_compliance_events, 0) as open_compliance_events,
  greatest(c.updated_at, coalesce(wr.updated_at, c.updated_at), coalesce(cap.last_updated_at, c.updated_at)) as last_activity_at
from wealth_advisors.advisor_assignments aa
join wealth_advisors.clients c on c.id = aa.client_id
left join lateral (
  select a1.total_score, a1.classification, a1.assessment_date
  from wealth_advisors.assessments a1
  where a1.client_id = c.id
  order by a1.assessment_date desc
  limit 1
) a on true
left join lateral (
  select w1.id, w1.primary_pathway, w1.status, w1.updated_at
  from wealth_advisors.wealth_roadmaps w1
  where w1.client_id = c.id
  order by w1.updated_at desc
  limit 1
) wr on true
left join lateral (
  select
    count(*) filter (where ra.status not in ('completed','cancelled'))::bigint as open_actions,
    min(ra.due_date) filter (where ra.status not in ('completed','cancelled')) as next_action_due_date
  from wealth_advisors.roadmap_actions ra
  where ra.roadmap_id = wr.id
) act on true
left join lateral (
  select
    count(*) filter (where cr.readiness_status not in ('declined','closed','funded'))::bigint as open_capital_requests,
    sum(cr.amount_requested) as capital_requested,
    min(cr.currency)::text as currency,
    max(cr.updated_at) as last_updated_at
  from wealth_advisors.capital_requests cr
  where cr.client_id = c.id
) cap on true
left join lateral (
  select
    count(*) filter (where r.status not in ('closed','declined','cancelled'))::bigint as open_referrals,
    min(r.follow_up_date) filter (where r.status not in ('closed','declined','cancelled')) as next_follow_up_date
  from wealth_advisors.referrals r
  where r.client_id = c.id
) ref on true
left join lateral (
  select count(*) filter (where ce.status not in ('resolved','closed'))::bigint as open_compliance_events
  from wealth_advisors.compliance_events ce
  where ce.client_id = c.id
) comp on true
where aa.active = true;

create or replace view public.wa_capital_pipeline
with (security_invoker = true)
as
select
  cr.id as capital_request_id,
  cr.client_id,
  c.legal_name as client_name,
  cr.enterprise_id,
  e.legal_name as enterprise_name,
  cr.amount_requested,
  cr.currency,
  cr.purpose,
  cr.requested_structure,
  cr.readiness_status,
  cr.assigned_advisor_user_id,
  cr.created_at,
  cr.updated_at,
  coalesce(ev.referred_amount, 0::numeric) as referred_amount,
  coalesce(ev.approved_amount, 0::numeric) as approved_amount,
  coalesce(ev.closed_amount, 0::numeric) as closed_amount,
  coalesce(ev.funded_amount, 0::numeric) as funded_amount,
  ev.last_event_at
from wealth_advisors.capital_requests cr
join wealth_advisors.clients c on c.id = cr.client_id
left join wealth_advisors.enterprises e on e.id = cr.enterprise_id
left join lateral (
  select
    sum(ce.event_amount) filter (where ce.event_type = 'referred') as referred_amount,
    sum(ce.event_amount) filter (where ce.event_type = 'approved') as approved_amount,
    sum(ce.event_amount) filter (where ce.event_type = 'closed') as closed_amount,
    sum(ce.event_amount) filter (where ce.event_type = 'funded') as funded_amount,
    max(ce.event_at) as last_event_at
  from wealth_advisors.capital_events ce
  where ce.capital_request_id = cr.id
) ev on true;

create or replace view public.wa_executive_command_summary
with (security_invoker = true)
as
select
  eps.active_clients,
  eps.assessments_completed,
  eps.average_fri_score,
  eps.capital_ready_requests,
  eps.capital_requested,
  eps.capital_referred,
  eps.capital_approved,
  eps.capital_closed,
  eps.capital_funded,
  eps.verified_outcomes,
  eps.open_compliance_events,
  now() as generated_at
from wealth_advisors.executive_pipeline_summary eps
where (select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive']));

revoke all on public.wa_client_portal_overview from anon;
revoke all on public.wa_advisor_crm_queue from anon;
revoke all on public.wa_capital_pipeline from anon;
revoke all on public.wa_executive_command_summary from anon;

grant select on public.wa_client_portal_overview to authenticated, service_role;
grant select on public.wa_advisor_crm_queue to authenticated, service_role;
grant select on public.wa_capital_pipeline to authenticated, service_role;
grant select on public.wa_executive_command_summary to authenticated, service_role;

comment on view public.wa_client_portal_overview is 'Phase VI-C client portal read surface; security_invoker enforces underlying Wealth Advisors RLS.';
comment on view public.wa_advisor_crm_queue is 'Phase VI-C advisor CRM queue; security_invoker enforces underlying Wealth Advisors RLS.';
comment on view public.wa_capital_pipeline is 'Phase VI-C capital pipeline read surface; security_invoker enforces underlying Wealth Advisors RLS.';
comment on view public.wa_executive_command_summary is 'Phase VI-C executive command summary restricted to VP Wealth Advisors, compliance, and executive roles.';
