create or replace function sourceenergy_one.create_genesis_package(
  p_impact_report_id uuid,
  p_approval_id uuid,
  p_schema_version text,
  p_package jsonb,
  p_package_hash text
) returns uuid
language plpgsql
security definer
set search_path = sourceenergy_one, pg_temp
as $$
declare
  ir sourceenergy_one.impact_reports%rowtype;
  ga sourceenergy_one.genesis_approvals%rowtype;
  gp_id uuid;
  pkg_subject text;
  p4 jsonb;
  dim jsonb;
  dim_name text;
begin
  if p_package is null or jsonb_typeof(p_package) <> 'object' then raise exception 'genesis package must be a JSON object'; end if;
  if p_schema_version is null or btrim(p_schema_version) = '' then raise exception 'schema version required'; end if;
  if p_package_hash is null or p_package_hash !~ '^[0-9a-fA-F]{64}$' then raise exception 'package hash must be 64 hex characters'; end if;

  select * into ir from sourceenergy_one.impact_reports where id=p_impact_report_id for update;
  if not found then raise exception 'impact report not found'; end if;
  if ir.status <> 'approved' then raise exception 'impact report not approved'; end if;

  select * into ga from sourceenergy_one.genesis_approvals where id=p_approval_id for update;
  if not found then raise exception 'genesis approval not found'; end if;
  if ga.impact_report_id <> ir.id then raise exception 'approval does not match impact report'; end if;
  if ga.decision <> 'approve' then raise exception 'genesis approval decision is not approve'; end if;
  if coalesce(nullif(btrim(ga.actor_ref),''),ga.actor_id::text) is null then raise exception 'human authorizing actor required'; end if;
  if ga.consent_receipt_id is null or btrim(ga.consent_receipt_id)='' then raise exception 'consent receipt required'; end if;

  pkg_subject := nullif(btrim(p_package->>'subject_id'),'');
  if pkg_subject is null or pkg_subject <> ir.subject_id then raise exception 'package subject does not match approved impact report'; end if;
  if coalesce((p_package->>'human_approved')::boolean,false) is not true then raise exception 'package must attest human_approved=true'; end if;
  if nullif(btrim(p_package->>'authorization_attestation'),'') is null then raise exception 'authorization attestation required'; end if;
  if nullif(btrim(p_package->>'jurisdiction'),'') is null then raise exception 'jurisdiction required'; end if;
  if p_package ? 'raw_purpose_discovery' or p_package ? 'responses' then raise exception 'raw Purpose Discovery narrative prohibited in Genesis package'; end if;

  p4 := p_package->'economic_4p_profile';
  if p4 is null or jsonb_typeof(p4) <> 'object' then raise exception 'economic_4p_profile required'; end if;
  if nullif(btrim(p4->>'version'),'') is null then raise exception '4P profile version required'; end if;
  if nullif(btrim(p4->>'approved_by'),'') is null then raise exception '4P human approver required'; end if;
  if nullif(btrim(p4->>'approval_attestation'),'') is null then raise exception '4P approval attestation required'; end if;

  foreach dim_name in array array['purpose','product','people','profit'] loop
    dim := p4->dim_name;
    if dim is null or jsonb_typeof(dim) <> 'object' then raise exception '4P dimension % required',dim_name; end if;
    if nullif(btrim(dim->>'statement'),'') is null then raise exception '4P dimension % statement required',dim_name; end if;
    if nullif(btrim(dim->>'source_hash'),'') is null then raise exception '4P dimension % source hash required',dim_name; end if;
    if nullif(btrim(dim->>'version'),'') is null then raise exception '4P dimension % version required',dim_name; end if;
    if jsonb_typeof(dim->'evidence_refs') <> 'array' or jsonb_array_length(dim->'evidence_refs')=0 then raise exception '4P dimension % evidence required',dim_name; end if;
    if exists(select 1 from jsonb_array_elements_text(dim->'evidence_refs') e(value) where nullif(btrim(e.value),'') is null) then raise exception '4P dimension % contains blank evidence reference',dim_name; end if;
  end loop;

  insert into sourceenergy_one.genesis_packages(subject_id,impact_report_id,approval_id,schema_version,package,package_hash)
  values(ir.subject_id,ir.id,ga.id,p_schema_version,p_package,lower(p_package_hash)) returning id into gp_id;

  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(gen_random_uuid(),ir.subject_id,ga.actor_id,'genesis_package_created','genesis_package',gp_id::text,
    jsonb_build_object('impact_report_id',ir.id,'approval_id',ga.id,'schema_version',p_schema_version,'package_hash',lower(p_package_hash),'economic_4p_profile_version',p4->>'version','economic_4p_approved_by',p4->>'approved_by'));
  return gp_id;
end;
$$;

revoke all on function sourceenergy_one.create_genesis_package(uuid,uuid,text,jsonb,text) from public, anon, authenticated;
grant execute on function sourceenergy_one.create_genesis_package(uuid,uuid,text,jsonb,text) to service_role;
