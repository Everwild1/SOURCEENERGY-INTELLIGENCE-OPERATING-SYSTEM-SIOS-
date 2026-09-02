create unique index if not exists genesis_packages_prior_genesis_unique_idx
on sourceenergy_one.genesis_packages ((package->>'prior_genesis_id'))
where nullif(package->>'prior_genesis_id','') is not null;

create or replace function sourceenergy_one.finalize_genesis_supersession(
  p_nomination_id uuid,
  p_new_impact_report_id uuid,
  p_new_genesis_approval_id uuid,
  p_schema_version text,
  p_package jsonb,
  p_package_hash text,
  p_actor_ref text
) returns uuid
language plpgsql
security definer
set search_path=sourceenergy_one,pg_temp
as $$
declare
  n sourceenergy_one.genesis_evolution_nominations%rowtype;
  prior_g sourceenergy_one.genesis_packages%rowtype;
  ir sourceenergy_one.impact_reports%rowtype;
  ga sourceenergy_one.genesis_approvals%rowtype;
  new_gid uuid;
  pkg_prior text;
  pkg_4p jsonb;
begin
  if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
  if p_package is null or jsonb_typeof(p_package)<>'object' then raise exception 'Genesis package object required'; end if;

  select * into n from sourceenergy_one.genesis_evolution_nominations where id=p_nomination_id for update;
  if not found then raise exception 'Genesis evolution nomination not found'; end if;
  if n.status<>'approval_required' then raise exception 'nomination is not awaiting final supersession'; end if;
  if n.genesis_approval_id is null then raise exception 'nomination has no bound Genesis approval'; end if;
  if n.genesis_approval_id<>p_new_genesis_approval_id then raise exception 'supplied Genesis approval does not match nomination approval'; end if;

  perform sourceenergy_one.require_spirit_gate('genesis_evolution_nomination',n.id);

  select * into prior_g from sourceenergy_one.genesis_packages where id=n.prior_genesis_id for update;
  if not found then raise exception 'prior Genesis not found'; end if;
  if prior_g.subject_id<>n.subject_id then raise exception 'prior Genesis subject mismatch'; end if;
  if exists(select 1 from sourceenergy_one.genesis_packages g where g.package->>'prior_genesis_id'=prior_g.id::text) then raise exception 'prior Genesis already superseded'; end if;

  select * into ir from sourceenergy_one.impact_reports where id=p_new_impact_report_id for update;
  if not found then raise exception 'new impact report not found'; end if;
  if ir.subject_id<>n.subject_id then raise exception 'new impact report subject mismatch'; end if;
  if ir.status<>'approved' then raise exception 'new impact report not approved'; end if;
  if ir.id=prior_g.impact_report_id then raise exception 'superseding Genesis requires a new impact report'; end if;
  perform sourceenergy_one.require_spirit_gate('impact_report',ir.id);

  select * into ga from sourceenergy_one.genesis_approvals where id=p_new_genesis_approval_id for update;
  if not found then raise exception 'new Genesis approval not found'; end if;
  if ga.impact_report_id<>ir.id then raise exception 'new Genesis approval does not belong to new impact report'; end if;
  if ga.decision<>'approve' then raise exception 'new Genesis approval is not approve'; end if;
  if coalesce(nullif(btrim(ga.actor_ref),''),ga.actor_id::text) is null then raise exception 'human Genesis approver required'; end if;
  if ga.consent_receipt_id is null or btrim(ga.consent_receipt_id)='' then raise exception 'Genesis approval consent required'; end if;
  if ga.decided_at<=n.created_at then raise exception 'Genesis approval must post-date evolution nomination'; end if;
  perform sourceenergy_one.require_spirit_gate('genesis_approval',ga.id);

  pkg_prior:=nullif(btrim(p_package->>'prior_genesis_id'),'');
  if pkg_prior is null or pkg_prior<>prior_g.id::text then raise exception 'package prior_genesis_id must exactly match prior Genesis'; end if;
  if nullif(btrim(p_package->>'subject_id'),'')<>n.subject_id then raise exception 'package subject mismatch'; end if;
  pkg_4p:=p_package->'economic_4p_profile';
  if pkg_4p is null or pkg_4p<>n.proposed_4p_profile then raise exception 'package 4P profile must exactly equal approved evolution nomination'; end if;

  perform sourceenergy_one.validate_4p_typed_evidence(n.subject_id,pkg_4p);

  new_gid:=sourceenergy_one.create_genesis_package(
    p_new_impact_report_id,
    p_new_genesis_approval_id,
    p_schema_version,
    p_package,
    p_package_hash
  );

  update sourceenergy_one.genesis_evolution_nominations
  set status='consumed',superseding_genesis_id=new_gid,updated_at=now()
  where id=n.id;

  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),n.subject_id,auth.uid(),'genesis_supersession_finalized','genesis_package',new_gid::text,
    jsonb_build_object('prior_genesis_id',prior_g.id,'nomination_id',n.id,'new_impact_report_id',ir.id,'new_genesis_approval_id',ga.id,'actor_ref',btrim(p_actor_ref)));

  return new_gid;
end;
$$;

revoke all on function sourceenergy_one.finalize_genesis_supersession(uuid,uuid,uuid,text,jsonb,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.finalize_genesis_supersession(uuid,uuid,uuid,text,jsonb,text,text) to service_role;
comment on function sourceenergy_one.finalize_genesis_supersession(uuid,uuid,uuid,text,jsonb,text,text) is 'Atomic G2+ finalization gate. Requires prior Genesis, human-confirmed material evolution nomination, nomination Spirit Gate, new approved impact report, new bound human Genesis approval, Spirit Gate on impact/approval, exact nominated 4P equality, typed evidence, and append-only prior_genesis linkage.';
