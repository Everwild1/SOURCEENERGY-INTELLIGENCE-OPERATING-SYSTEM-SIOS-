begin;
select plan(26);

select has_table('public','setc_insurance_policy_parties','policy parties table exists');
select has_table('public','setc_insurance_policy_coverages','policy coverages table exists');
select has_table('public','setc_insurance_policy_terms','policy terms table exists');
select has_table('public','setc_insurance_policy_documents','policy documents table exists');
select has_table('public','setc_insurance_policy_lifecycle_events','policy lifecycle table exists');
select has_table('public','setc_insurance_policy_renewals','policy renewals table exists');

select col_type_is('public','setc_insurance_policy_coverages','limit_amount','numeric','coverage limit uses numeric');
select col_type_is('public','setc_insurance_policy_coverages','aggregate_limit_amount','numeric','aggregate limit uses numeric');
select col_type_is('public','setc_insurance_policy_coverages','deductible_amount','numeric','deductible uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_parties'::regclass),'policy parties RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_coverages'::regclass),'policy coverages RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_terms'::regclass),'policy terms RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_documents'::regclass),'policy documents RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_lifecycle_events'::regclass),'policy lifecycle RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_policy_renewals'::regclass),'policy renewals RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_policy_documents','SELECT'),'anon cannot select policy documents');
select ok(not has_table_privilege('authenticated','public.setc_insurance_policy_documents','SELECT'),'authenticated cannot select policy documents');
select ok(has_table_privilege('service_role','public.setc_insurance_policy_documents','SELECT'),'service role can select policy documents');
select ok(not has_table_privilege('anon','public.setc_insurance_policy_lifecycle_events','SELECT'),'anon cannot select lifecycle events');
select ok(not has_table_privilege('authenticated','public.setc_insurance_policy_lifecycle_events','SELECT'),'authenticated cannot select lifecycle events');
select ok(has_table_privilege('service_role','public.setc_insurance_policy_lifecycle_events','SELECT'),'service role can select lifecycle events');

select throws_ok(
  $$insert into public.setc_insurance_policy_documents(policy_id,document_type,document_ref,authoritative)
    values ('00000000-0000-0000-0000-000000000001','policy','TEST-DOC',true)$$,
  '23514', null, 'authoritative document requires authority evidence'
);

select throws_ok(
  $$insert into public.setc_insurance_policy_lifecycle_events(policy_id,event_type,effective_at,authority_status)
    values ('00000000-0000-0000-0000-000000000001','activate',now(),'verified')$$,
  '23514', null, 'verified lifecycle authority requires evidence'
);

select throws_ok(
  $$insert into public.setc_insurance_policy_parties(policy_id,organization_oid,party_role,authority_status)
    values ('00000000-0000-0000-0000-000000000001','SETC-OID-TEST','carrier','verified')$$,
  '23514', null, 'verified party authority requires evidence'
);

select throws_ok(
  $$insert into public.setc_insurance_policy_renewals(predecessor_policy_id,successor_policy_id)
    values ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001')$$,
  '23514', null, 'policy cannot renew into itself'
);

select lives_ok($$select 1 from public.setc_insurance_policy_coverages limit 1$$,'policy coverages queryable by owner');
select lives_ok($$select 1 from public.setc_insurance_policy_terms limit 1$$,'policy terms queryable by owner');

select * from finish();
rollback;
