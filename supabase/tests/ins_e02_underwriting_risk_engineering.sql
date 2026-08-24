begin;
select plan(24);

select has_table('public','setc_insurance_risk_factors','risk factors table exists');
select has_table('public','setc_insurance_risk_factor_observations','risk factor observations table exists');
select has_table('public','setc_insurance_risk_controls','risk controls table exists');
select has_table('public','setc_insurance_underwriting_decisions','underwriting decisions table exists');
select has_table('public','setc_insurance_underwriting_referrals','underwriting referrals table exists');

select col_type_is('public','setc_insurance_risk_factor_observations','normalized_score','numeric','normalized score uses numeric');
select col_type_is('public','setc_insurance_risk_factor_observations','confidence_score','numeric','confidence score uses numeric');
select col_type_is('public','setc_insurance_risk_controls','effectiveness_score','numeric','effectiveness score uses numeric');
select col_type_is('public','setc_insurance_underwriting_decisions','decision_score','numeric','decision score uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_risk_factors'::regclass),'risk factors RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_risk_factor_observations'::regclass),'observations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_risk_controls'::regclass),'controls RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_underwriting_decisions'::regclass),'decisions RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_underwriting_referrals'::regclass),'referrals RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_underwriting_decisions','SELECT'),'anon cannot select underwriting decisions');
select ok(not has_table_privilege('authenticated','public.setc_insurance_underwriting_decisions','SELECT'),'authenticated cannot select underwriting decisions');
select ok(has_table_privilege('service_role','public.setc_insurance_underwriting_decisions','SELECT'),'service role can select underwriting decisions');
select ok(not has_table_privilege('anon','public.setc_insurance_risk_factor_observations','SELECT'),'anon cannot select factor observations');
select ok(not has_table_privilege('authenticated','public.setc_insurance_risk_factor_observations','SELECT'),'authenticated cannot select factor observations');
select ok(has_table_privilege('service_role','public.setc_insurance_risk_factor_observations','SELECT'),'service role can select factor observations');

select throws_ok(
  $$insert into public.setc_insurance_risk_factor_observations(risk_assessment_id,risk_factor_id,observing_organization_oid,confidence_score)
    values ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','SETC-OID-TEST',1.2)$$,
  '23514',
  null,
  'confidence score above 1 is rejected'
);

select throws_ok(
  $$insert into public.setc_insurance_risk_controls(risk_object_id,organization_oid,control_code,control_name,control_type,effectiveness_score)
    values ('00000000-0000-0000-0000-000000000003','SETC-OID-TEST','CTRL-1','Test','preventive',-0.1)$$,
  '23514',
  null,
  'negative effectiveness score is rejected'
);

select throws_ok(
  $$insert into public.setc_insurance_underwriting_decisions(underwriting_submission_id,deciding_organization_oid,decision_type,authority_status)
    values ('00000000-0000-0000-0000-000000000004','SETC-OID-TEST','refer','verified')$$,
  '23514',
  null,
  'verified authority requires evidence'
);

select lives_ok(
  $$select 1 from public.setc_insurance_underwriting_referrals limit 1$$,
  'referral table is queryable by test owner'
);

select * from finish();
rollback;
