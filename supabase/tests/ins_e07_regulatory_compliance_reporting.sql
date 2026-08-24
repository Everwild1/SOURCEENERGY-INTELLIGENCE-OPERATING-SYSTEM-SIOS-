begin;
select plan(30);

select has_table('public','setc_insurance_regulatory_authorities','regulatory authorities table exists');
select has_table('public','setc_insurance_license_records','license records table exists');
select has_table('public','setc_insurance_regulatory_obligations','regulatory obligations table exists');
select has_table('public','setc_insurance_regulatory_filings','regulatory filings table exists');
select has_table('public','setc_insurance_compliance_attestations','compliance attestations table exists');
select has_table('public','setc_insurance_compliance_exceptions','compliance exceptions table exists');
select has_table('public','setc_insurance_regulatory_correspondence','regulatory correspondence table exists');
select has_table('public','setc_insurance_compliance_audit_events','compliance audit events table exists');

select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_regulatory_authorities'::regclass),'regulatory authorities RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_license_records'::regclass),'license records RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_regulatory_obligations'::regclass),'regulatory obligations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_regulatory_filings'::regclass),'regulatory filings RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_compliance_attestations'::regclass),'attestations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_compliance_exceptions'::regclass),'exceptions RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_regulatory_correspondence'::regclass),'correspondence RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.setc_insurance_compliance_audit_events'::regclass),'audit events RLS enabled');

select ok(not has_table_privilege('anon','public.setc_insurance_license_records','SELECT'),'anon cannot select license records');
select ok(not has_table_privilege('authenticated','public.setc_insurance_license_records','SELECT'),'authenticated cannot select license records');
select ok(has_table_privilege('service_role','public.setc_insurance_license_records','SELECT'),'service role can select license records');

select throws_ok($$insert into public.setc_insurance_license_records(organization_oid,regulatory_authority_id,license_type,jurisdiction_code,license_status) values ('TEST','00000000-0000-0000-0000-000000000001','producer','US-NY','evidence_verified')$$,'23514',null,'verified license requires external evidence');
select throws_ok($$insert into public.setc_insurance_license_records(organization_oid,regulatory_authority_id,license_type,jurisdiction_code,license_status,external_evidence_ref) values ('TEST','00000000-0000-0000-0000-000000000001','producer','US-NY','active_reference','evidence://license')$$,'23514',null,'active license reference also requires authoritative document');
select throws_ok($$insert into public.setc_insurance_regulatory_filings(organization_oid,filing_type,filing_status) values ('TEST','annual','submitted_reference')$$,'23514',null,'submitted filing requires external evidence');
select throws_ok($$insert into public.setc_insurance_compliance_attestations(organization_oid,attestation_type,attestation_status,evidence_refs) values ('TEST','annual','evidence_supported','[]'::jsonb)$$,'23514',null,'supported attestation requires authority and evidence');
select throws_ok($$insert into public.setc_insurance_compliance_exceptions(exception_type,exception_status) values ('test','closed')$$,'23514',null,'closed exception requires disposition evidence');
select throws_ok($$insert into public.setc_insurance_license_records(organization_oid,regulatory_authority_id,license_type,jurisdiction_code,effective_at,expires_at) values ('TEST','00000000-0000-0000-0000-000000000001','producer','US-NY',now(),now()-interval '1 day')$$,'23514',null,'license expiry must follow effective date');
select throws_ok($$insert into public.setc_insurance_regulatory_obligations(obligation_code,obligation_type,jurisdiction_code,effective_at,expires_at) values ('TEST','filing','US-NY',now(),now()-interval '1 day')$$,'23514',null,'obligation expiry must follow effective date');
select throws_ok($$insert into public.setc_insurance_regulatory_filings(organization_oid,filing_type,period_start,period_end) values ('TEST','annual',date '2026-12-31',date '2026-01-01')$$,'23514',null,'filing period end cannot precede start');
select throws_ok($$insert into public.setc_insurance_compliance_exceptions(exception_type,opened_at,closed_at) values ('test',now(),now()-interval '1 day')$$,'23514',null,'exception close cannot precede open');

select lives_ok($$select 1 from public.setc_insurance_regulatory_authorities limit 1$$,'regulatory authorities queryable by owner');
select lives_ok($$select 1 from public.setc_insurance_compliance_audit_events limit 1$$,'audit events queryable by owner');
select lives_ok($$select 1 from public.setc_insurance_regulatory_correspondence limit 1$$,'correspondence queryable by owner');

select * from finish();
rollback;
