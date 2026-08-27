begin;
select plan(31);

select has_table('public','setc_insurance_loss_events','loss events table exists');
select has_table('public','setc_insurance_fnol_records','FNOL table exists');
select has_table('public','setc_insurance_claim_parties','claim parties table exists');
select has_table('public','setc_insurance_claim_assignments','claim assignments table exists');
select has_table('public','setc_insurance_claim_reserve_movements','reserve movements table exists');
select has_table('public','setc_insurance_claim_documents','claim documents table exists');
select has_table('public','setc_insurance_coverage_reviews','coverage reviews table exists');
select has_table('public','setc_insurance_claim_financial_references','financial references table exists');
select has_table('public','setc_insurance_claim_recoveries','claim recoveries table exists');
select has_table('public','setc_insurance_claim_lifecycle_events','claim lifecycle table exists');

select col_type_is('public','setc_insurance_claim_reserve_movements','amount_delta','numeric','reserve delta uses numeric');
select col_type_is('public','setc_insurance_claim_reserve_movements','resulting_reserve','numeric','resulting reserve uses numeric');
select col_type_is('public','setc_insurance_claim_financial_references','amount','numeric','financial reference amount uses numeric');
select col_type_is('public','setc_insurance_claim_recoveries','expected_amount','numeric','expected recovery uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_loss_events'::regclass),'loss events RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_fnol_records'::regclass),'FNOL RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_parties'::regclass),'claim parties RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_assignments'::regclass),'assignments RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_reserve_movements'::regclass),'reserves RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_documents'::regclass),'documents RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_coverage_reviews'::regclass),'coverage reviews RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_financial_references'::regclass),'financial references RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_recoveries'::regclass),'recoveries RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_claim_lifecycle_events'::regclass),'lifecycle RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_claim_assignments','SELECT'),'anon cannot select assignments');
select ok(not has_table_privilege('authenticated','public.setc_insurance_claim_assignments','SELECT'),'authenticated cannot select assignments');
select ok(has_table_privilege('service_role','public.setc_insurance_claim_assignments','SELECT'),'service role can select assignments');

select throws_ok($$insert into public.setc_insurance_claim_assignments(claim_id,assigned_organization_oid,assignment_role,authority_status) values ('00000000-0000-0000-0000-000000000001','TEST','adjuster','verified')$$,'23514',null,'verified assignment authority requires evidence');
select throws_ok($$insert into public.setc_insurance_claim_documents(claim_id,document_type,document_ref,authoritative) values ('00000000-0000-0000-0000-000000000001','report','ref',true)$$,'23514',null,'authoritative document requires evidence');
select throws_ok($$insert into public.setc_insurance_claim_financial_references(claim_id,reference_type,external_status) values ('00000000-0000-0000-0000-000000000001','payment','externally_confirmed')$$,'23514',null,'confirmed financial reference requires evidence');
select throws_ok($$insert into public.setc_insurance_claim_reserve_movements(claim_id,movement_type,amount_delta,currency_code,resulting_reserve) values ('00000000-0000-0000-0000-000000000001','establish',100,'USD',-1)$$,'23514',null,'resulting reserve cannot be negative');

select * from finish();
rollback;
