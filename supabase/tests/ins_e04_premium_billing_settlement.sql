begin;
select plan(28);

select has_table('public','setc_insurance_premium_schedules','premium schedules table exists');
select has_table('public','setc_insurance_invoices','invoices table exists');
select has_table('public','setc_insurance_payments','payments table exists');
select has_table('public','setc_insurance_payment_allocations','allocations table exists');
select has_table('public','setc_insurance_refunds','refunds table exists');
select has_table('public','setc_insurance_commissions_fees','commissions fees table exists');
select has_table('public','setc_insurance_settlement_reconciliations','reconciliations table exists');

select col_type_is('public','setc_insurance_premium_schedules','total_amount','numeric','premium total uses numeric');
select col_type_is('public','setc_insurance_invoices','amount_due','numeric','invoice amount uses numeric');
select col_type_is('public','setc_insurance_payments','amount','numeric','payment amount uses numeric');
select col_type_is('public','setc_insurance_refunds','amount','numeric','refund amount uses numeric');
select col_type_is('public','setc_insurance_commissions_fees','amount','numeric','fee amount uses numeric');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_premium_schedules'::regclass),'premium schedules RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_invoices'::regclass),'invoices RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_payments'::regclass),'payments RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_payment_allocations'::regclass),'allocations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_refunds'::regclass),'refunds RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_commissions_fees'::regclass),'commissions fees RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_settlement_reconciliations'::regclass),'reconciliations RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_payments','SELECT'),'anon cannot select payments');
select ok(not has_table_privilege('authenticated','public.setc_insurance_payments','SELECT'),'authenticated cannot select payments');
select ok(has_table_privilege('service_role','public.setc_insurance_payments','SELECT'),'service role can select payments');

select throws_ok(
  $$insert into public.setc_insurance_payments(amount,currency_code,internal_status)
    values (100,'USD','externally_confirmed')$$,
  '23514', null, 'external payment confirmation requires evidence'
);
select throws_ok(
  $$insert into public.setc_insurance_refunds(amount,currency_code,refund_status)
    values (50,'USD','externally_confirmed')$$,
  '23514', null, 'external refund confirmation requires evidence'
);
select throws_ok(
  $$insert into public.setc_insurance_settlement_reconciliations(reconciliation_type,reconciliation_status)
    values ('payment','matched')$$,
  '23514', null, 'matched reconciliation requires evidence'
);
select throws_ok(
  $$insert into public.setc_insurance_premium_schedules(policy_id,schedule_type,total_amount,currency_code,installment_count)
    values ('00000000-0000-0000-0000-000000000001','monthly',100,'USD',0)$$,
  '23514', null, 'installment count must be positive'
);
select throws_ok(
  $$insert into public.setc_insurance_payment_allocations(payment_id,invoice_id,allocated_amount)
    values ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',0)$$,
  '23514', null, 'allocation must be positive'
);
select lives_ok($$select 1 from public.setc_insurance_invoices limit 1$$,'invoices queryable by owner');

select * from finish();
rollback;
