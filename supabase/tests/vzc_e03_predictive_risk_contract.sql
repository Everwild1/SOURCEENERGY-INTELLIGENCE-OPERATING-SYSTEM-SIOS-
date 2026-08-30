-- VZC E03 predictive-risk contract assertions.
begin;
do $$
declare m uuid; a uuid;
begin
  insert into vzc.risk_model_registry(model_key,model_version,intended_use)
  values ('vzc.contract.risk','0.0.1','Contract validation only') returning risk_model_id into m;

  insert into vzc.risk_assessments(risk_model_id,subject_type,subject_key,assessment_window_start,assessment_window_end,risk_score,risk_band,confidence,explanation)
  values (m,'corridor','CI-VZC-E03',now()-interval '5 minutes',now(),0.8,'high',0.9,'{"reason":"contract"}'::jsonb)
  returning risk_assessment_id into a;

  begin
    insert into vzc.risk_recommendations(risk_assessment_id,recommendation_type,recommendation_text,recommendation_state)
    values (a,'planning','Review corridor controls','accepted_for_planning');
    raise exception 'Expected planning authority constraint failure did not occur';
  exception when check_violation then null;
  end;

  begin
    update vzc.risk_assessments set operational_authority=true where risk_assessment_id=a;
    raise exception 'Expected predictive operational-authority constraint failure did not occur';
  exception when check_violation then null;
  end;

  begin
    insert into vzc.risk_recommendations(risk_assessment_id,recommendation_type,recommendation_text,execution_reference)
    values (a,'planning','Unsafe execution linkage','EXEC-1');
    raise exception 'Expected recommendation execution constraint failure did not occur';
  exception when check_violation then null;
  end;
end $$;
rollback;
