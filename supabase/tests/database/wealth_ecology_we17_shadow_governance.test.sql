-- WE-17 shadow evaluation: no production state is committed.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='wealth_ecology' and c.relname='decisions'), 'decisions has RLS enabled');
select ok(not has_schema_privilege('anon','wealth_ecology','USAGE'), 'anon has no Wealth Ecology schema usage');
select ok(not has_schema_privilege('authenticated','wealth_ecology','USAGE'), 'authenticated has no Wealth Ecology schema usage');
select ok(has_schema_privilege('service_role','wealth_ecology','USAGE'), 'service_role has Wealth Ecology schema usage');
select ok(not has_table_privilege('authenticated','wealth_ecology.decisions','SELECT'), 'authenticated cannot select decisions');
select ok(has_table_privilege('service_role','wealth_ecology.decisions','SELECT'), 'service_role can select decisions');

set local role service_role;
insert into wealth_ecology.objects(id,object_type,canonical_name,evidence_refs) values
 ('11111111-1111-4111-8111-111111111177','PURPOSE','WE17 Shadow Purpose',jsonb_build_array('WE17-E1')),
 ('22222222-2222-4222-8222-222222222277','OPPORTUNITY','WE17 Shadow Opportunity',jsonb_build_array('WE17-E2'));
insert into wealth_ecology.p4_pathways(id,purpose_ref,status,evidence_refs) values
 ('33333333-3333-4333-8333-333333333377','11111111-1111-4111-8111-111111111177','ACTIVE',jsonb_build_array('WE17-E3'));
insert into wealth_ecology.decisions(id,pathway_id,purpose_ref,decision_question,evidence_refs,recommendation,recommendation_basis,decision_status) values
 ('44444444-4444-4444-8444-444444444477','33333333-3333-4333-8333-333333333377','11111111-1111-4111-8111-111111111177','WE-17 shadow decision?',jsonb_build_array('WE17-E4'),jsonb_build_object('action','shadow-only'),jsonb_build_object('basis','test'),'RECOMMENDED');
insert into wealth_ecology.execution_authorizations(id,pathway_id,wealth_object_id,authorization_state,decision_question,recommendation_basis,evidence_refs,required_approval_refs) values
 ('55555555-5555-4555-8555-555555555577','33333333-3333-4333-8333-333333333377','22222222-2222-4222-8222-222222222277','RECOMMENDED','WE-17 shadow authorization?',jsonb_build_object('decision_ref','44444444-4444-4444-8444-444444444477'),jsonb_build_array('WE17-E5'),jsonb_build_array('HUMAN-APPROVAL-REQUIRED'));

select results_eq(
 $$select count(*)::bigint from wealth_ecology.integration_outbox where aggregate_id in ('44444444-4444-4444-8444-444444444477','55555555-5555-4555-8555-555555555577')$$,
 $$values (2::bigint)$$,
 'decision and authorization create events enter the transactional outbox'
);
select results_eq(
 $$select count(*)::bigint from wealth_ecology.integration_outbox where aggregate_id in ('44444444-4444-4444-8444-444444444477','55555555-5555-4555-8555-555555555577') and contract_version='we.sios.v1'$$,
 $$values (2::bigint)$$,
 'WE-16 events use we.sios.v1 contract'
);
select throws_ok(
 $$update wealth_ecology.decisions set decision_status='APPROVED' where id='44444444-4444-4444-8444-444444444477'$$,
 'P0001',
 'WE-10 approval/execution requires accountable human approver',
 'decision cannot cross approval gate without accountable human approver'
);

select * from finish();
rollback;
