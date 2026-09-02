do $$
declare
  v_wwn_oid text := 'SETC-OID-' || md5('SourceEnergy Group|Working Warriors Network|Center of Excellence');
  v_seg_oid text := 'SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d';
  v_rel_id text := 'SETC-REL-' || md5('SourceEnergy Group|OPERATES|Working Warriors Network');
begin
  insert into public.setc_organizations
    (oid,legal_name,normalized_name,organization_type,verification_state)
  values
    (v_wwn_oid,'Working Warriors Network','working warriors network','program','PENDING_VERIFICATION')
  on conflict (oid) do update
    set legal_name=excluded.legal_name,
        normalized_name=excluded.normalized_name,
        organization_type=excluded.organization_type,
        verification_state=case when public.setc_organizations.verification_state in ('VERIFIED','ENHANCED_VERIFICATION','ACCREDITED') then public.setc_organizations.verification_state else 'PENDING_VERIFICATION' end,
        updated_at=now();

  if not exists (select 1 from public.setc_organization_relationships where relationship_id=v_rel_id) then
    insert into public.setc_organization_relationships
      (relationship_id,source_organization_id,target_organization_id,relationship_type,state,effective_from,evidence_reference,asserted_by)
    values
      (v_rel_id,v_seg_oid,v_wwn_oid,'OPERATES','PENDING_VERIFICATION',now(),'https://sourceenergyglobal.org/center-of-excellence/working-warriors-network/','USER_DIRECTIVE_2026-08-28');
  end if;

  update workforce_ecology.pilot_identity_mappings
     set principal_reference=v_wwn_oid,
         operating_unit_id=v_wwn_oid,
         evidence_reference='public.setc_organizations:'||v_wwn_oid||' | Working Warriors Network | PENDING_VERIFICATION',
         status='pending',
         verified_at=null
   where calculation_version='WEI-1.0'
     and principal_type='operating_unit'
     and principal_reference='WWN-COE';

  update workforce_ecology.pilot_authorizations
     set operating_unit_id=v_wwn_oid,
         conditions=conditions || jsonb_build_object(
           'candidate_operating_unit','Working Warriors Network',
           'canonical_setc_oid',v_wwn_oid,
           'candidate_identity_status','pending_verification',
           'relationship_to_sourceenergy_group','OPERATES:PENDING_VERIFICATION'
         )
   where calculation_version='WEI-1.0'
     and authorization_code='WEI-1.0-LIMITED-PILOT-2026-08-28';
end $$;
