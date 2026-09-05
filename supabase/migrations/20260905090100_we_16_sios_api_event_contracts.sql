-- WE-16: SIOS API/event contracts for Wealth Ecology governance
-- Authoritative backend contract version: we.sios.v1

create table if not exists wealth_ecology.integration_outbox (
  id uuid primary key default gen_random_uuid(),
  aggregate_type text not null check (aggregate_type in ('DECISION','EXECUTION_AUTHORIZATION','SOURCE_COIN_BOUNDARY_REVIEW')),
  aggregate_id uuid not null,
  event_type text not null,
  event_version integer not null default 1 check (event_version > 0),
  contract_version text not null default 'we.sios.v1',
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  published_at timestamptz,
  publication_attempts integer not null default 0 check (publication_attempts >= 0),
  last_error text,
  correlation_id uuid,
  causation_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists we_integration_outbox_unpublished_idx
  on wealth_ecology.integration_outbox (occurred_at, id) where published_at is null;
create index if not exists we_integration_outbox_aggregate_idx
  on wealth_ecology.integration_outbox (aggregate_type, aggregate_id, occurred_at);

alter table wealth_ecology.integration_outbox enable row level security;
revoke all on wealth_ecology.integration_outbox from public, anon, authenticated;
grant all on wealth_ecology.integration_outbox to service_role;

create policy service_role_full_access_integration_outbox
  on wealth_ecology.integration_outbox
  for all to service_role using (true) with check (true);

create or replace function wealth_ecology.emit_sios_governance_event()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, wealth_ecology
as $$
declare
  v_aggregate_type text;
  v_aggregate_id uuid;
  v_event_type text;
  v_payload jsonb;
begin
  if tg_table_name = 'decisions' then
    v_aggregate_type := 'DECISION';
    v_aggregate_id := new.id;
    v_event_type := case when tg_op = 'INSERT' then 'wealth_ecology.decision.created' else 'wealth_ecology.decision.status_changed' end;
    if tg_op = 'UPDATE' and new.decision_status is not distinct from old.decision_status then return new; end if;
    v_payload := jsonb_build_object('decision_id',new.id,'pathway_id',new.pathway_id,'purpose_ref',new.purpose_ref,'decision_status',new.decision_status,'human_approver_ref',new.human_approver_ref,'version',new.version,'review_date',new.review_date);
  elsif tg_table_name = 'execution_authorizations' then
    v_aggregate_type := 'EXECUTION_AUTHORIZATION';
    v_aggregate_id := new.id;
    v_event_type := case when tg_op = 'INSERT' then 'wealth_ecology.execution_authorization.created' else 'wealth_ecology.execution_authorization.state_changed' end;
    if tg_op = 'UPDATE' and new.authorization_state is not distinct from old.authorization_state then return new; end if;
    v_payload := jsonb_build_object('authorization_id',new.id,'pathway_id',new.pathway_id,'wealth_object_id',new.wealth_object_id,'authorization_state',new.authorization_state,'approved_by_actor_ref',new.approved_by_actor_ref,'approved_at',new.approved_at,'execution_system',new.execution_system,'execution_object_ref',new.execution_object_ref);
  elsif tg_table_name = 'source_coin_boundary_reviews' then
    v_aggregate_type := 'SOURCE_COIN_BOUNDARY_REVIEW';
    v_aggregate_id := new.id;
    v_event_type := case when tg_op = 'INSERT' then 'wealth_ecology.source_coin_boundary_review.created' else 'wealth_ecology.source_coin_boundary_review.status_changed' end;
    if tg_op = 'UPDATE' and new.review_status is not distinct from old.review_status then return new; end if;
    v_payload := jsonb_build_object('boundary_review_id',new.id,'authorization_id',new.authorization_id,'review_status',new.review_status,'jurisdiction',new.jurisdiction,'legal_regulatory_classification',new.legal_regulatory_classification,'approval_authority',new.approval_authority,'finality_authority',new.finality_authority,'reviewed_by',new.reviewed_by,'reviewed_at',new.reviewed_at);
  else
    raise exception 'Unsupported WE-16 event source: %', tg_table_name;
  end if;

  insert into wealth_ecology.integration_outbox(aggregate_type,aggregate_id,event_type,event_version,contract_version,payload,correlation_id)
  values(v_aggregate_type,v_aggregate_id,v_event_type,1,'we.sios.v1',v_payload,case when v_aggregate_type='DECISION' then v_aggregate_id else null end);
  return new;
end;
$$;

revoke execute on function wealth_ecology.emit_sios_governance_event() from public, anon, authenticated;
grant execute on function wealth_ecology.emit_sios_governance_event() to service_role;

drop trigger if exists trg_we_sios_decision_event on wealth_ecology.decisions;
create trigger trg_we_sios_decision_event after insert or update on wealth_ecology.decisions for each row execute function wealth_ecology.emit_sios_governance_event();
drop trigger if exists trg_we_sios_execution_authorization_event on wealth_ecology.execution_authorizations;
create trigger trg_we_sios_execution_authorization_event after insert or update on wealth_ecology.execution_authorizations for each row execute function wealth_ecology.emit_sios_governance_event();
drop trigger if exists trg_we_sios_source_coin_boundary_event on wealth_ecology.source_coin_boundary_reviews;
create trigger trg_we_sios_source_coin_boundary_event after insert or update on wealth_ecology.source_coin_boundary_reviews for each row execute function wealth_ecology.emit_sios_governance_event();

create or replace view wealth_ecology.decision_governance_projection
with (security_invoker = true)
as
select d.id as decision_id,d.pathway_id,d.purpose_ref,d.decision_question,d.decision_status,d.human_approver_ref,d.review_date,d.version,d.updated_at,
       ea.id as authorization_id,ea.authorization_state,ea.approved_by_actor_ref,ea.approved_at,ea.execution_system,ea.execution_object_ref,
       sc.id as source_coin_boundary_review_id,sc.review_status as source_coin_review_status,sc.jurisdiction as source_coin_jurisdiction,
       sc.legal_regulatory_classification,sc.approval_authority as source_coin_approval_authority,sc.finality_authority as source_coin_finality_authority
from wealth_ecology.decisions d
left join wealth_ecology.execution_authorizations ea on ea.pathway_id=d.pathway_id
left join wealth_ecology.source_coin_boundary_reviews sc on sc.authorization_id=ea.id;

revoke all on wealth_ecology.decision_governance_projection from public, anon, authenticated;
grant select on wealth_ecology.decision_governance_projection to service_role;

comment on table wealth_ecology.integration_outbox is 'WE-16 transactional integration outbox for SIOS. Recommendation, approval, execution, and Source Coin boundary review remain distinct governance states.';
comment on view wealth_ecology.decision_governance_projection is 'WE-16 service-only SECURITY INVOKER projection of decision, execution authorization, and Source Coin boundary review states.';
