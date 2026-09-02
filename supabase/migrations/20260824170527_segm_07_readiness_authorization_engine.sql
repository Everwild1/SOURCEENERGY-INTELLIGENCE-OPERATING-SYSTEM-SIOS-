create index if not exists segm_authorities_evidence_idx on segm.authorities(evidence_id);
create index if not exists segm_authz_authority_idx on segm.authorization_decisions(authority_id);
create index if not exists segm_authz_evidence_idx on segm.authorization_decisions(evidence_id);
create index if not exists segm_capability_institution_idx on segm.capability_registry(institution_id);
create index if not exists segm_capability_evidence_idx on segm.capability_registry(evidence_id);
create index if not exists segm_compliance_requirement_idx on segm.compliance_assessments(requirement_id);
create index if not exists segm_compliance_evidence_idx on segm.compliance_assessments(evidence_id);
create index if not exists segm_contract_vehicle_institution_idx on segm.contract_vehicle_references(institution_id);
create index if not exists segm_contract_vehicle_rgl_contract_idx on segm.contract_vehicle_references(rgl_contract_id);
create index if not exists segm_contract_vehicle_energy_agreement_idx on segm.contract_vehicle_references(energy_agreement_id);
create index if not exists segm_contract_vehicle_evidence_idx on segm.contract_vehicle_references(evidence_id);
create index if not exists segm_dhn_institution_idx on segm.dhn_adapter_links(institution_id);
create index if not exists segm_dhn_org_idx on segm.dhn_adapter_links(dhn_organization_id);
create index if not exists segm_dhn_approval_idx on segm.dhn_adapter_links(dhn_authorization_approval_event_id);
create index if not exists segm_dhn_evidence_idx on segm.dhn_adapter_links(evidence_id);
create index if not exists segm_energy_institution_idx on segm.energy_adapter_links(institution_id);
create index if not exists segm_energy_project_org_idx on segm.energy_adapter_links(project_organization_link_id);
create index if not exists segm_energy_agreement_idx on segm.energy_adapter_links(energy_agreement_id);
create index if not exists segm_energy_evidence_idx on segm.energy_adapter_links(evidence_id);
create index if not exists segm_evidence_iotf_idx on segm.evidence_items(iotf_organization_evidence_id);
create index if not exists segm_export_capability_idx on segm.export_control_reviews(capability_id);
create index if not exists segm_export_org_idx on segm.export_control_reviews(operating_organization_oid);
create index if not exists segm_export_evidence_idx on segm.export_control_reviews(evidence_id);
create index if not exists segm_eligibility_evidence_idx on segm.organizational_eligibility(evidence_id);
create index if not exists segm_proc_case_originating_institution_idx on segm.procurement_cases(originating_institution_id);
create index if not exists segm_proc_case_operating_org_idx on segm.procurement_cases(operating_organization_oid);
create index if not exists segm_rgl_institution_idx on segm.rgl_adapter_links(institution_id);
create index if not exists segm_rgl_contract_idx on segm.rgl_adapter_links(rgl_contract_id);
create index if not exists segm_rgl_mandate_idx on segm.rgl_adapter_links(government_corridor_mandate_id);
create index if not exists segm_rgl_evidence_idx on segm.rgl_adapter_links(evidence_id);

create or replace view segm.case_readiness
with (security_invoker = true)
as
select
  pc.id as procurement_case_id,
  pc.case_code,
  pc.procurement_stage,
  pc.bid_decision,
  pc.award_status,
  pc.operating_organization_oid,
  pc.originating_institution_id,
  exists (
    select 1 from segm.organizational_eligibility oe
    join segm.evidence_items ei on ei.id = oe.evidence_id
    where oe.operating_organization_oid = pc.operating_organization_oid
      and oe.status = 'VERIFIED'
      and (oe.effective_from is null or oe.effective_from <= current_date)
      and (oe.effective_to is null or oe.effective_to >= current_date)
      and ei.evidence_state = 'VERIFIED'
      and (ei.effective_from is null or ei.effective_from <= now())
      and (ei.effective_to is null or ei.effective_to >= now())
  ) as eligibility_ready,
  not exists (
    select 1 from segm.compliance_assessments ca
    where ca.procurement_case_id = pc.id
      and ca.assessment_status = 'NONCOMPLIANT'
  ) as compliance_clear,
  not exists (
    select 1 from segm.export_control_reviews er
    where (er.procurement_case_id = pc.id or er.operating_organization_oid = pc.operating_organization_oid)
      and er.review_status in ('PROHIBITED','ESCALATED','LICENSE_REQUIRED','CONTROLLED','IN_REVIEW','NOT_ASSESSED')
  ) as export_control_clear,
  exists (
    select 1 from segm.authorization_decisions ad
    join segm.authorities a on a.id = ad.authority_id
    join segm.evidence_items ei on ei.id = ad.evidence_id
    where ad.procurement_case_id = pc.id
      and ad.decision_type = 'AUTHORITY_TO_BID'
      and ad.decision_status = 'APPROVED'
      and (ad.expires_at is null or ad.expires_at >= now())
      and a.status = 'VERIFIED'
      and (a.effective_from is null or a.effective_from <= now())
      and (a.effective_to is null or a.effective_to >= now())
      and ei.evidence_state = 'VERIFIED'
      and (ei.effective_to is null or ei.effective_to >= now())
  ) as authority_to_bid_ready,
  exists (
    select 1 from segm.contract_vehicle_references cv
    join segm.evidence_items ei on ei.id = cv.evidence_id
    where cv.operating_organization_oid = pc.operating_organization_oid
      and cv.verification_state = 'VERIFIED'
      and (cv.effective_from is null or cv.effective_from <= current_date)
      and (cv.effective_to is null or cv.effective_to >= current_date)
      and ei.evidence_state = 'VERIFIED'
      and (ei.effective_to is null or ei.effective_to >= now())
  ) as contract_vehicle_ready,
  exists (
    select 1 from segm.authorization_decisions ad
    join segm.authorities a on a.id = ad.authority_id
    join segm.evidence_items ei on ei.id = ad.evidence_id
    where ad.procurement_case_id = pc.id
      and ad.decision_type = 'AUTHORITY_TO_PERFORM'
      and ad.decision_status = 'APPROVED'
      and (ad.expires_at is null or ad.expires_at >= now())
      and a.status = 'VERIFIED'
      and (a.effective_from is null or a.effective_from <= now())
      and (a.effective_to is null or a.effective_to >= now())
      and ei.evidence_state = 'VERIFIED'
      and (ei.effective_to is null or ei.effective_to >= now())
  ) as authority_to_perform_ready
from segm.procurement_cases pc;

create or replace view segm.case_readiness_score
with (security_invoker = true)
as
select
  cr.*,
  ((cr.eligibility_ready::int + cr.compliance_clear::int + cr.export_control_clear::int +
    cr.authority_to_bid_ready::int + cr.contract_vehicle_ready::int + cr.authority_to_perform_ready::int) * 100 / 6) as readiness_score,
  case
    when cr.eligibility_ready and cr.compliance_clear and cr.export_control_clear and cr.authority_to_bid_ready
      then true else false end as bid_ready,
  case
    when cr.eligibility_ready and cr.compliance_clear and cr.export_control_clear and
         cr.authority_to_bid_ready and cr.contract_vehicle_ready and cr.authority_to_perform_ready and cr.award_status = 'AWARDED'
      then true else false end as performance_ready
from segm.case_readiness cr;

create or replace view segm.expiry_watch_90d
with (security_invoker = true)
as
select 'EVIDENCE'::text as object_type, ei.id as object_id, ei.institution_id,
       ei.title as object_label, ei.effective_to as expires_at,
       greatest(0, ceil(extract(epoch from (ei.effective_to - now())) / 86400.0))::int as days_remaining
from segm.evidence_items ei
where ei.evidence_state = 'VERIFIED'
  and ei.effective_to is not null
  and ei.effective_to >= now()
  and ei.effective_to <= now() + interval '90 days'
union all
select 'AUTHORITY'::text, a.id, a.institution_id,
       a.authority_type || ': ' || a.authority_scope, a.effective_to,
       greatest(0, ceil(extract(epoch from (a.effective_to - now())) / 86400.0))::int
from segm.authorities a
where a.status = 'VERIFIED'
  and a.effective_to is not null
  and a.effective_to >= now()
  and a.effective_to <= now() + interval '90 days'
union all
select 'AUTHORIZATION_DECISION'::text, ad.id, pc.originating_institution_id,
       ad.decision_type || ' / ' || pc.case_code, ad.expires_at,
       greatest(0, ceil(extract(epoch from (ad.expires_at - now())) / 86400.0))::int
from segm.authorization_decisions ad
join segm.procurement_cases pc on pc.id = ad.procurement_case_id
where ad.decision_status = 'APPROVED'
  and ad.expires_at is not null
  and ad.expires_at >= now()
  and ad.expires_at <= now() + interval '90 days';

create or replace function segm.enforce_authorization_preconditions()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_case segm.procurement_cases%rowtype;
  v_authority segm.authorities%rowtype;
  v_evidence segm.evidence_items%rowtype;
  v_has_eligibility boolean;
  v_compliance_clear boolean;
  v_export_clear boolean;
  v_has_bid_approval boolean;
  v_has_contract_vehicle boolean;
begin
  if new.decision_status <> 'APPROVED' then
    return new;
  end if;

  select * into v_case from segm.procurement_cases where id = new.procurement_case_id;
  if not found then raise exception 'SEGM authorization denied: procurement case not found'; end if;
  if v_case.operating_organization_oid is null then raise exception 'SEGM authorization denied: operating organization is required'; end if;
  if new.authority_id is null or new.evidence_id is null then raise exception 'SEGM authorization denied: verified authority and evidence are required'; end if;
  if new.decision_reference is null or btrim(new.decision_reference) = '' or new.decided_by is null or btrim(new.decided_by) = '' or new.decided_at is null then
    raise exception 'SEGM authorization denied: decision reference, decision maker, and decision timestamp are required';
  end if;

  select * into v_authority from segm.authorities where id = new.authority_id;
  if not found or v_authority.status <> 'VERIFIED' or (v_authority.effective_from is not null and v_authority.effective_from > now()) or (v_authority.effective_to is not null and v_authority.effective_to < now()) then
    raise exception 'SEGM authorization denied: authority is not currently verified';
  end if;

  select * into v_evidence from segm.evidence_items where id = new.evidence_id;
  if not found or v_evidence.evidence_state <> 'VERIFIED' or (v_evidence.effective_from is not null and v_evidence.effective_from > now()) or (v_evidence.effective_to is not null and v_evidence.effective_to < now()) then
    raise exception 'SEGM authorization denied: evidence is not currently verified';
  end if;

  select exists (
    select 1 from segm.organizational_eligibility oe
    join segm.evidence_items ei on ei.id = oe.evidence_id
    where oe.operating_organization_oid = v_case.operating_organization_oid
      and oe.status = 'VERIFIED'
      and (oe.effective_from is null or oe.effective_from <= current_date)
      and (oe.effective_to is null or oe.effective_to >= current_date)
      and ei.evidence_state = 'VERIFIED'
      and (ei.effective_to is null or ei.effective_to >= now())
  ) into v_has_eligibility;

  select not exists (
    select 1 from segm.compliance_assessments ca
    where ca.procurement_case_id = v_case.id and ca.assessment_status = 'NONCOMPLIANT'
  ) into v_compliance_clear;

  select not exists (
    select 1 from segm.export_control_reviews er
    where (er.procurement_case_id = v_case.id or er.operating_organization_oid = v_case.operating_organization_oid)
      and er.review_status in ('PROHIBITED','ESCALATED','LICENSE_REQUIRED','CONTROLLED','IN_REVIEW','NOT_ASSESSED')
  ) into v_export_clear;

  if not v_has_eligibility then raise exception 'SEGM authorization denied: verified organizational eligibility is required'; end if;
  if not v_compliance_clear then raise exception 'SEGM authorization denied: unresolved noncompliance exists'; end if;
  if not v_export_clear then raise exception 'SEGM authorization denied: export-control review is unresolved or restrictive'; end if;

  if new.decision_type = 'AUTHORITY_TO_PERFORM' then
    if v_case.award_status <> 'AWARDED' then raise exception 'SEGM authorization denied: performance authority requires AWARDED status'; end if;

    select exists (
      select 1 from segm.authorization_decisions ad
      where ad.procurement_case_id = v_case.id
        and ad.decision_type = 'AUTHORITY_TO_BID'
        and ad.decision_status = 'APPROVED'
        and (ad.expires_at is null or ad.expires_at >= now())
    ) into v_has_bid_approval;
    if not v_has_bid_approval then raise exception 'SEGM authorization denied: current Authority to Bid approval is required'; end if;

    select exists (
      select 1 from segm.contract_vehicle_references cv
      join segm.evidence_items ei on ei.id = cv.evidence_id
      where cv.operating_organization_oid = v_case.operating_organization_oid
        and cv.verification_state = 'VERIFIED'
        and (cv.effective_from is null or cv.effective_from <= current_date)
        and (cv.effective_to is null or cv.effective_to >= current_date)
        and ei.evidence_state = 'VERIFIED'
        and (ei.effective_to is null or ei.effective_to >= now())
    ) into v_has_contract_vehicle;
    if not v_has_contract_vehicle then raise exception 'SEGM authorization denied: verified current contract vehicle is required'; end if;
  end if;

  return new;
end;
$$;

revoke all on function segm.enforce_authorization_preconditions() from public;
revoke all on function segm.enforce_authorization_preconditions() from anon;
revoke all on function segm.enforce_authorization_preconditions() from authenticated;

drop trigger if exists segm_authorization_preconditions on segm.authorization_decisions;
create trigger segm_authorization_preconditions
before insert or update of decision_status, decision_type, authority_id, evidence_id, procurement_case_id
on segm.authorization_decisions
for each row execute function segm.enforce_authorization_preconditions();

create or replace function segm.prevent_unauthorized_execution_state()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ready boolean;
begin
  if new.procurement_stage = 'PERFORMANCE' and old.procurement_stage is distinct from 'PERFORMANCE' then
    select performance_ready into v_ready from segm.case_readiness_score where procurement_case_id = new.id;
    if coalesce(v_ready,false) is false then
      raise exception 'SEGM stage transition denied: case is not performance-ready';
    end if;
  end if;
  if new.bid_decision = 'BID' and old.bid_decision is distinct from 'BID' then
    select bid_ready into v_ready from segm.case_readiness_score where procurement_case_id = new.id;
    if coalesce(v_ready,false) is false then
      raise exception 'SEGM bid decision denied: case is not bid-ready';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function segm.prevent_unauthorized_execution_state() from public;
revoke all on function segm.prevent_unauthorized_execution_state() from anon;
revoke all on function segm.prevent_unauthorized_execution_state() from authenticated;

drop trigger if exists segm_execution_gate on segm.procurement_cases;
create trigger segm_execution_gate
before update of procurement_stage, bid_decision
on segm.procurement_cases
for each row execute function segm.prevent_unauthorized_execution_state();
