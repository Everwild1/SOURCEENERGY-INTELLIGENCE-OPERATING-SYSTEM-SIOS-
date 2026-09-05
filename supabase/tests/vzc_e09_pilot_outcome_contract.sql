-- VZC E09 pilot and outcome contract smoke assertions
begin;

do $$
declare
  p uuid;
  e uuid;
begin
  insert into vzc.pilot_registry(pilot_code,pilot_class,scope_reference)
  values ('VZC-E09-CONTRACT-'||gen_random_uuid()::text,'municipal_safety_corridor','scope:test') returning pilot_id into p;

  begin
    update vzc.pilot_registry set pilot_state='pilot_approved' where pilot_id=p;
    raise exception 'expected pilot approval gate failure';
  exception when check_violation then null;
  end;

  insert into vzc.pilot_outcome_evaluations(pilot_id,evaluation_method_reference)
  values (p,'method:test') returning pilot_outcome_evaluation_id into e;

  begin
    update vzc.pilot_outcome_evaluations set evaluation_state='positive' where pilot_outcome_evaluation_id=e;
    raise exception 'expected completed evaluation evidence gate failure';
  exception when check_violation then null;
  end;

  begin
    insert into vzc.pilot_scale_decisions(pilot_id,pilot_outcome_evaluation_id,decision,evidence_reference)
    values(p,e,'production_approved','evidence:test');
    raise exception 'expected production approval authority gate failure';
  exception when check_violation then null;
  end;

  update vzc.pilot_outcome_evaluations
     set evaluation_state='inconclusive', evidence_reference='evidence:inconclusive', reviewer_authority_ref='reviewer:test', completed_at=now()
   where pilot_outcome_evaluation_id=e;

  insert into vzc.pilot_scale_decisions(pilot_id,pilot_outcome_evaluation_id,decision,evidence_reference)
  values(p,e,'iterate','evidence:iterate');
end $$;

rollback;
