alter table workforce_ecology.measurement_observations add column if not exists cohort_size integer;
alter table workforce_ecology.measurement_observations add constraint measurement_observations_cohort_size_positive check (cohort_size is null or cohort_size > 0);

insert into workforce_ecology.pilot_identity_mappings
(calculation_version,principal_type,principal_reference,mapping_role,status,evidence_reference)
values
('WEI-1.0','organization','SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d','pilot_parent_organization','pending','public.setc_organizations:SourceEnergy Group:PENDING_VERIFICATION')
on conflict (calculation_version,principal_type,principal_reference,mapping_role)
do update set status='pending', evidence_reference=excluded.evidence_reference, verified_at=null;

create or replace function workforce_ecology.validate_wei_observation_v1()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_minimum_cohort integer;
  v_evidence_class text;
begin
  select mr.minimum_cohort_size, mr.evidence_class into v_minimum_cohort, v_evidence_class
  from workforce_ecology.metric_registry mr where mr.metric_id=new.metric_id;
  if v_minimum_cohort is null then raise exception 'WEI metric registry entry not found for observation metric_id %', new.metric_id; end if;
  if v_evidence_class in ('voluntary_aggregated_pulse','network_indicator','collaboration_indicator','retention_continuity_signal','community_participation_record') then
    if new.cohort_size is null then raise exception 'cohort_size is required for WEI evidence class %', v_evidence_class; end if;
    if new.cohort_size < v_minimum_cohort then raise exception 'cohort_size % is below approved minimum % for WEI metric', new.cohort_size, v_minimum_cohort; end if;
  end if;
  return new;
end;
$$;
revoke all on function workforce_ecology.validate_wei_observation_v1() from public, anon, authenticated;
grant execute on function workforce_ecology.validate_wei_observation_v1() to service_role;
drop trigger if exists trg_validate_wei_observation_v1 on workforce_ecology.measurement_observations;
create trigger trg_validate_wei_observation_v1 before insert or update of metric_id,cohort_size on workforce_ecology.measurement_observations for each row execute function workforce_ecology.validate_wei_observation_v1();

create or replace view workforce_ecology.sios_wei_pilot_readiness
with (security_invoker=true)
as
select
  pv.version_name as calculation_version,
  pv.status as policy_status,
  pv.approval_scope,
  pa.authorization_code,
  pa.status as pilot_authorization_status,
  pg.status as production_gate_status,
  count(gr.reviewer_role_id) filter (where gr.required_for_pilot) as required_reviewer_roles,
  count(gr.reviewer_role_id) filter (where gr.required_for_pilot and gr.status='active' and gr.assigned_principal_reference is not null) as assigned_reviewer_roles,
  (select count(*) from workforce_ecology.pilot_identity_mappings pim where pim.calculation_version=pv.version_name and pim.status='verified') as verified_identity_mappings,
  (pv.status='approved' and pv.approval_scope='limited_pilot' and pa.status in ('approved_pending_assignments','active')
   and count(gr.reviewer_role_id) filter (where gr.required_for_pilot)>0
   and count(gr.reviewer_role_id) filter (where gr.required_for_pilot and gr.status='active' and gr.assigned_principal_reference is not null)=count(gr.reviewer_role_id) filter (where gr.required_for_pilot)
   and (select count(*) from workforce_ecology.pilot_identity_mappings pim where pim.calculation_version=pv.version_name and pim.status='verified')>0) as pilot_ready,
  pa.conditions,
  (select count(*) from workforce_ecology.pilot_identity_mappings pim where pim.calculation_version=pv.version_name and pim.status='pending') as pending_identity_mappings
from workforce_ecology.policy_versions pv
join workforce_ecology.pilot_authorizations pa on pa.calculation_version=pv.version_name
left join workforce_ecology.production_gate pg on pg.calculation_version=pv.version_name
left join workforce_ecology.governance_reviewers gr on gr.calculation_version=pv.version_name
where pv.version_name='WEI-1.0'
group by pv.version_name,pv.status,pv.approval_scope,pa.authorization_code,pa.status,pg.status,pa.conditions;
revoke all on workforce_ecology.sios_wei_pilot_readiness from public, anon, authenticated;
grant select on workforce_ecology.sios_wei_pilot_readiness to service_role;
