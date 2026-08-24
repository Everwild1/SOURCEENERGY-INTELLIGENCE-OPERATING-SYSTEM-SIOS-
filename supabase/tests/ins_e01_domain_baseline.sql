begin;

select plan(25);

select has_table('public', 'setc_insurance_products', 'insurance products exists');
select has_table('public', 'setc_insurance_risk_objects', 'risk objects exists');
select has_table('public', 'setc_insurance_risk_assessments', 'risk assessments exists');
select has_table('public', 'setc_insurance_requirements', 'insurance requirements exists');
select has_table('public', 'setc_insurance_underwriting_submissions', 'underwriting submissions exists');
select has_table('public', 'setc_insurance_quotes', 'quotes exists');
select has_table('public', 'setc_insurance_policies', 'policies exists');
select has_table('public', 'setc_insurance_endorsements', 'endorsements exists');
select has_table('public', 'setc_insurance_premiums', 'premiums exists');
select has_table('public', 'setc_insurance_claims', 'claims exists');

select col_type_is('public','setc_insurance_products','organization_oid','text','product organization uses canonical text OID');
select col_type_is('public','setc_insurance_policies','insured_organization_oid','text','insured organization uses canonical text OID');
select col_type_is('public','setc_insurance_premiums','amount','numeric(24,6)','premium uses exact numeric');
select col_type_is('public','setc_insurance_claims','claimed_amount','numeric(24,6)','claim amount uses exact numeric');

select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_insurance_products'), 'RLS enabled products');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_insurance_risk_objects'), 'RLS enabled risk objects');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_insurance_underwriting_submissions'), 'RLS enabled submissions');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_insurance_policies'), 'RLS enabled policies');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_insurance_claims'), 'RLS enabled claims');

select ok(not has_table_privilege('anon','public.setc_insurance_policies','SELECT'), 'anon cannot select policies');
select ok(not has_table_privilege('authenticated','public.setc_insurance_policies','SELECT'), 'authenticated cannot select policies');
select ok(not has_table_privilege('anon','public.setc_insurance_claims','SELECT'), 'anon cannot select claims');
select ok(not has_table_privilege('authenticated','public.setc_insurance_claims','SELECT'), 'authenticated cannot select claims');
select ok(has_table_privilege('service_role','public.setc_insurance_policies','SELECT'), 'service role can select policies');
select ok(has_table_privilege('service_role','public.setc_insurance_claims','SELECT'), 'service role can select claims');

select * from finish();
rollback;