insert into workforce_ecology.pilot_identity_mappings
(calculation_version,principal_type,principal_reference,operating_unit_id,mapping_role,status,evidence_reference)
select 'WEI-1.0','operating_unit','WWN-COE', 'WWN-COE','candidate_pilot_operating_unit','pending','https://sourceenergyglobal.org/center-of-excellence/working-warriors-network/ | Public page confirms Working Warriors Network under Centers of Excellence; canonical SETC operating-unit identity not yet verified'
where not exists (
 select 1 from workforce_ecology.pilot_identity_mappings
 where calculation_version='WEI-1.0' and principal_type='operating_unit' and principal_reference='WWN-COE' and mapping_role='candidate_pilot_operating_unit'
);

update workforce_ecology.pilot_authorizations
set operating_unit_id='WWN-COE',
    conditions = conditions || jsonb_build_object(
      'candidate_operating_unit','Working Warriors Network',
      'candidate_operating_unit_reference','WWN-COE',
      'candidate_identity_status','pending_verification',
      'public_evidence_reference','https://sourceenergyglobal.org/center-of-excellence/working-warriors-network/'
    )
where calculation_version='WEI-1.0'
  and authorization_code='WEI-1.0-LIMITED-PILOT-2026-08-28'
  and status='approved_pending_assignments';
