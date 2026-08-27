begin;
select plan(35);

select has_table('public','setc_insurance_accounting_frameworks','accounting frameworks table exists');
select has_table('public','setc_insurance_accounting_periods','accounting periods table exists');
select has_table('public','setc_insurance_ledger_mappings','ledger mappings table exists');
select has_table('public','setc_insurance_technical_reserves','technical reserves table exists');
select has_table('public','setc_insurance_actuarial_valuations','actuarial valuations table exists');
select has_table('public','setc_insurance_capital_requirements','capital requirements table exists');
select has_table('public','setc_insurance_available_capital','available capital table exists');
select has_table('public','setc_insurance_solvency_snapshots','solvency snapshots table exists');
select has_table('public','setc_insurance_accounting_reconciliations','accounting reconciliations table exists');
select has_table('public','setc_insurance_capital_filing_references','capital filing references table exists');

select col_type_is('public','setc_insurance_technical_reserves','gross_amount','numeric','gross reserve uses numeric');
select col_type_is('public','setc_insurance_technical_reserves','ceded_amount','numeric','ceded reserve uses numeric');
select col_type_is('public','setc_insurance_technical_reserves','net_amount','numeric','net reserve uses numeric');
select col_type_is('public','setc_insurance_capital_requirements','required_amount','numeric','capital requirement uses numeric');
select col_type_is('public','setc_insurance_available_capital','amount','numeric','available capital uses numeric');
select col_type_is('public','setc_insurance_solvency_snapshots','solvency_ratio','numeric','solvency ratio uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_accounting_frameworks'::regclass),'accounting frameworks RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_accounting_periods'::regclass),'accounting periods RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_ledger_mappings'::regclass),'ledger mappings RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_technical_reserves'::regclass),'technical reserves RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_actuarial_valuations'::regclass),'actuarial valuations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_capital_requirements'::regclass),'capital requirements RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_available_capital'::regclass),'available capital RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_solvency_snapshots'::regclass),'solvency snapshots RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_accounting_reconciliations'::regclass),'accounting reconciliations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_capital_filing_references'::regclass),'capital filing references RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_technical_reserves','SELECT'),'anon cannot select technical reserves');
select ok(not has_table_privilege('authenticated','public.setc_insurance_technical_reserves','SELECT'),'authenticated cannot select technical reserves');
select ok(has_table_privilege('service_role','public.setc_insurance_technical_reserves','SELECT'),'service role can select technical reserves');

select throws_ok($$insert into public.setc_insurance_accounting_periods(organization_oid,period_start,period_end) values ('TEST',date '2026-12-31',date '2026-01-01')$$,'23514',null,'accounting period end cannot precede start');
select throws_ok($$insert into public.setc_insurance_technical_reserves(organization_oid,accounting_period_id,reserve_type,gross_amount,ceded_amount,net_amount,currency_code) values ('TEST','00000000-0000-0000-0000-000000000001','case',100,120,0,'USD')$$,'23514',null,'ceded reserve cannot exceed gross reserve');
select throws_ok($$insert into public.setc_insurance_technical_reserves(organization_oid,accounting_period_id,reserve_type,gross_amount,ceded_amount,net_amount,currency_code) values ('TEST','00000000-0000-0000-0000-000000000001','case',100,20,70,'USD')$$,'23514',null,'reserve arithmetic must reconcile');
select throws_ok($$insert into public.setc_insurance_technical_reserves(organization_oid,accounting_period_id,reserve_type,gross_amount,ceded_amount,net_amount,currency_code,valuation_status) values ('TEST','00000000-0000-0000-0000-000000000001','case',100,20,80,'USD','actuarial_reference')$$,'23514',null,'actuarial reserve reference requires evidence');
select throws_ok($$insert into public.setc_insurance_actuarial_valuations(organization_oid,accounting_period_id,valuation_type,valuation_status) values ('TEST','00000000-0000-0000-0000-000000000001','reserve','opinion_reference')$$,'23514',null,'actuarial opinion reference requires document and authority evidence');
select throws_ok($$insert into public.setc_insurance_capital_requirements(organization_oid,requirement_type,required_amount,currency_code,requirement_status) values ('TEST','minimum_capital',100,'USD','regulatory_reference')$$,'23514',null,'regulatory capital reference requires evidence');
select throws_ok($$insert into public.setc_insurance_available_capital(organization_oid,capital_tier,amount,currency_code,valuation_status) values ('TEST','core',100,'USD','audited_reference')$$,'23514',null,'audited capital reference requires evidence');
select throws_ok($$insert into public.setc_insurance_solvency_snapshots(organization_oid,available_capital_amount,required_capital_amount,solvency_ratio,currency_code) values ('TEST',100,0,1.5,'USD')$$,'23514',null,'solvency ratio cannot be asserted with zero required capital');
select throws_ok($$insert into public.setc_insurance_accounting_reconciliations(organization_oid,reconciliation_type,reconciliation_status) values ('TEST','capital','matched')$$,'23514',null,'matched accounting reconciliation requires external evidence');
select throws_ok($$insert into public.setc_insurance_capital_filing_references(organization_oid,filing_type,filing_status) values ('TEST','annual','submitted_reference')$$,'23514',null,'capital filing submission reference requires evidence');

select * from finish();
rollback;
