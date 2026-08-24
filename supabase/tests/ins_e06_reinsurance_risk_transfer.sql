begin;
select plan(29);

select has_table('public','setc_insurance_reinsurance_arrangements','reinsurance arrangements table exists');
select has_table('public','setc_insurance_reinsurance_parties','reinsurance parties table exists');
select has_table('public','setc_insurance_reinsurance_layers','reinsurance layers table exists');
select has_table('public','setc_insurance_ceded_risk_allocations','ceded risk allocations table exists');
select has_table('public','setc_insurance_reinsurance_financial_references','reinsurance financial references table exists');
select has_table('public','setc_insurance_reinsurance_documents','reinsurance documents table exists');
select has_table('public','setc_insurance_reinsurance_collateral_references','collateral references table exists');
select has_table('public','setc_insurance_reinsurance_reconciliations','reinsurance reconciliations table exists');

select col_type_is('public','setc_insurance_reinsurance_layers','attachment_amount','numeric','attachment amount uses numeric');
select col_type_is('public','setc_insurance_reinsurance_layers','limit_amount','numeric','layer limit uses numeric');
select col_type_is('public','setc_insurance_reinsurance_parties','participation_pct','numeric','party participation uses numeric');
select col_type_is('public','setc_insurance_ceded_risk_allocations','ceded_pct','numeric','ceded percentage uses numeric');
select col_type_is('public','setc_insurance_reinsurance_financial_references','amount','numeric','financial amount uses numeric');
select col_type_is('public','setc_insurance_reinsurance_collateral_references','stated_amount','numeric','collateral amount uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_arrangements'::regclass),'arrangements RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_parties'::regclass),'parties RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_layers'::regclass),'layers RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_ceded_risk_allocations'::regclass),'ceded allocations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_financial_references'::regclass),'financial refs RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_documents'::regclass),'documents RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_collateral_references'::regclass),'collateral RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_reinsurance_reconciliations'::regclass),'reconciliations RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_reinsurance_arrangements','SELECT'),'anon cannot select arrangements');
select ok(not has_table_privilege('authenticated','public.setc_insurance_reinsurance_arrangements','SELECT'),'authenticated cannot select arrangements');
select ok(has_table_privilege('service_role','public.setc_insurance_reinsurance_arrangements','SELECT'),'service role can select arrangements');

select throws_ok($$insert into public.setc_insurance_reinsurance_arrangements(arrangement_type,arrangement_code,arrangement_status) values ('treaty','TEST-ACTIVE','active_reference')$$,'23514',null,'active arrangement requires authoritative evidence');
select throws_ok($$insert into public.setc_insurance_reinsurance_parties(reinsurance_arrangement_id,organization_oid,party_role,authority_status) values ('00000000-0000-0000-0000-000000000001','TEST','reinsurer','verified')$$,'23514',null,'verified reinsurance party requires authority evidence');
select throws_ok($$insert into public.setc_insurance_reinsurance_layers(reinsurance_arrangement_id,layer_number,attachment_amount,limit_amount,currency_code,participation_pct) values ('00000000-0000-0000-0000-000000000001',1,0,100,'USD',101)$$,'23514',null,'layer participation cannot exceed 100');
select throws_ok($$insert into public.setc_insurance_reinsurance_financial_references(reinsurance_arrangement_id,reference_type,amount,currency_code,external_status) values ('00000000-0000-0000-0000-000000000001','recoverable',100,'USD','externally_confirmed')$$,'23514',null,'confirmed financial reference requires external evidence');
select throws_ok($$insert into public.setc_insurance_reinsurance_collateral_references(reinsurance_arrangement_id,collateral_type,status) values ('00000000-0000-0000-0000-000000000001','trust','evidence_verified')$$,'23514',null,'verified collateral requires evidence');
select throws_ok($$insert into public.setc_insurance_reinsurance_reconciliations(reinsurance_arrangement_id,reconciliation_type,reconciliation_status) values ('00000000-0000-0000-0000-000000000001','settlement','matched')$$,'23514',null,'matched reconciliation requires external evidence');

select * from finish();
rollback;
