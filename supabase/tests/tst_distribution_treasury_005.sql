-- TST-WP07/WP08 contract and segregation-of-duties tests.
BEGIN;
DO $$
DECLARE c integer;
BEGIN
 SELECT count(*) INTO c FROM pg_class x JOIN pg_namespace n ON n.oid=x.relnamespace WHERE n.nspname='tst' AND x.relname IN ('payment_destinations','treasury_accounts','distributions','distribution_approvals','payments','reconciliations') AND x.relrowsecurity;
 IF c<>6 THEN RAISE EXCEPTION 'WP07/08 RLS incomplete: %/6',c; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='tst' AND table_name IN ('payment_destinations','treasury_accounts','distributions','distribution_approvals','payments','reconciliations') AND grantee IN ('anon','authenticated')) THEN RAISE EXCEPTION 'client grant leak'; END IF;
END $$;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES('SETC-OID-dddddddddddddddddddddddddddddddd','TST Treasury Test Org','tst treasury test org','FOUNDATION','VERIFIED') ON CONFLICT DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from)
VALUES('SETC-OID-dddddddddddddddddddddddddddddddd','TST-TREASURY','TST Treasury Test Org','ACTIVE','2026-08-23') ON CONFLICT DO NOTHING;

DO $$
DECLARE e uuid; f uuid; a uuid; b uuid; initiator uuid; approver uuid; executor uuid; reconciler uuid; dest uuid; acct uuid; d uuid; p uuid; rid uuid;
BEGIN
 SELECT stewardship_entity_id INTO e FROM tst.stewardship_entities WHERE stewardship_code='TST-TREASURY';
 INSERT INTO tst.funds(stewardship_entity_id,name,purpose,fund_type,currency,status,restriction_type) VALUES(e,'Treasury Test Fund','test','TITHE','USD','ACTIVE','PURPOSE_RESTRICTED') RETURNING fund_id INTO f;
 -- Seed received contribution through a valid calculation chain.
 INSERT INTO tst.tithe_elections(stewardship_entity_id,organization_oid,rate,basis_code,currency,status,effective_from) VALUES(e,'SETC-OID-dddddddddddddddddddddddddddddddd',0.10,'TEST','USD','ACTIVE','2026-08-01') RETURNING election_id INTO a;
 INSERT INTO tst.tithe_calculations(election_id,period_start,period_end,eligible_base,applied_rate,calculated_amount,currency,status) VALUES(a,'2026-08-01','2026-08-31',10000,0.10,1000,'USD','APPROVED') RETURNING calculation_id INTO a;
 INSERT INTO tst.contributions(calculation_id,fund_id,amount,currency,status,received_at) VALUES(a,f,1000,'USD','RECEIVED',now());
 INSERT INTO tst.allocations(fund_id,allocation_code,purpose,authorized_amount,committed_amount,disbursed_amount,currency,status) VALUES(f,'A1','pilot',800,0,0,'USD','ACTIVE') RETURNING allocation_id INTO a;
 INSERT INTO tst.beneficiaries(stewardship_entity_id,beneficiary_type,display_name,risk_tier,eligibility_status,compliance_status,conflict_status,related_party,next_review_date) VALUES(e,'INDIVIDUAL','Pilot Beneficiary','B1','ACTIVE','CLEAR','NONE',false,'2027-08-23') RETURNING beneficiary_id INTO b;
 INSERT INTO tst.participants(stewardship_entity_id,organization_oid,auth_user_id,display_name,status) VALUES
 (e,'SETC-OID-dddddddddddddddddddddddddddddddd','10000000-0000-0000-0000-000000000001','Initiator','ACTIVE'),
 (e,'SETC-OID-dddddddddddddddddddddddddddddddd','10000000-0000-0000-0000-000000000002','Trustee','ACTIVE'),
 (e,'SETC-OID-dddddddddddddddddddddddddddddddd','10000000-0000-0000-0000-000000000003','Treasury','ACTIVE'),
 (e,'SETC-OID-dddddddddddddddddddddddddddddddd','10000000-0000-0000-0000-000000000004','Reconciler','ACTIVE');
 SELECT participant_id INTO initiator FROM tst.participants WHERE auth_user_id='10000000-0000-0000-0000-000000000001';
 SELECT participant_id INTO approver FROM tst.participants WHERE auth_user_id='10000000-0000-0000-0000-000000000002';
 SELECT participant_id INTO executor FROM tst.participants WHERE auth_user_id='10000000-0000-0000-0000-000000000003';
 SELECT participant_id INTO reconciler FROM tst.participants WHERE auth_user_id='10000000-0000-0000-0000-000000000004';
 INSERT INTO tst.role_assignments(participant_id,stewardship_entity_id,organization_oid,role_code,status) VALUES
 (approver,e,'SETC-OID-dddddddddddddddddddddddddddddddd','TST_TRUSTEE','ACTIVE'),
 (executor,e,'SETC-OID-dddddddddddddddddddddddddddddddd','TST_TREASURY','ACTIVE'),
 (reconciler,e,'SETC-OID-dddddddddddddddddddddddddddddddd','TST_RECONCILER','ACTIVE');
 INSERT INTO tst.payment_destinations(beneficiary_id,destination_type,institution_name,masked_reference,currency,status,verified_by_participant_id,verified_at) VALUES(b,'BANK','Test Bank','****1234','USD','VERIFIED',approver,now()) RETURNING payment_destination_id INTO dest;
 INSERT INTO tst.treasury_accounts(stewardship_entity_id,institution_name,masked_reference,currency,status) VALUES(e,'Custody Bank','****9999','USD','ACTIVE') RETURNING treasury_account_id INTO acct;
 INSERT INTO tst.distributions(beneficiary_id,allocation_id,requested_amount,currency,purpose,requested_by_participant_id) VALUES(b,a,500,'USD','pilot grant',initiator) RETURNING distribution_id INTO d;
 PERFORM tst_private.submit_distribution(d);
 -- Initiator may not self-approve.
 BEGIN PERFORM tst_private.approve_distribution(d,initiator,500,'SELF'); RAISE EXCEPTION 'self approval unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='self approval unexpectedly allowed' THEN RAISE; END IF; END;
 PERFORM tst_private.approve_distribution(d,approver,500,'BOARD-TEST');
 PERFORM tst_private.release_to_treasury(d);
 -- Final approver may not execute.
 BEGIN PERFORM tst_private.execute_payment(d,acct,dest,approver,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','BAD'); RAISE EXCEPTION 'approver execution unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='approver execution unexpectedly allowed' THEN RAISE; END IF; END;
 p:=tst_private.execute_payment(d,acct,dest,executor,'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','PAY-1');
 -- One distribution cannot be paid twice.
 BEGIN INSERT INTO tst.payments(distribution_id,treasury_account_id,payment_destination_id,amount,currency,idempotency_key,executed_by_participant_id) VALUES(d,acct,dest,500,'USD','cccccccc-cccc-cccc-cccc-cccccccccccc',executor); RAISE EXCEPTION 'duplicate distribution payment unexpectedly allowed'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM tst_private.confirm_payment_settlement(p);
 -- Executor may not reconcile.
 BEGIN PERFORM tst_private.complete_reconciliation(p,executor,500,500); RAISE EXCEPTION 'executor reconciliation unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='executor reconciliation unexpectedly allowed' THEN RAISE; END IF; END;
 rid:=tst_private.complete_reconciliation(p,reconciler,500,500);
 IF (SELECT status FROM tst.distributions WHERE distribution_id=d)<>'RECONCILED' THEN RAISE EXCEPTION 'distribution not reconciled'; END IF;
 IF (SELECT disbursed_amount FROM tst.allocations WHERE allocation_id=a)<>500 THEN RAISE EXCEPTION 'allocation disbursement incorrect'; END IF;
END $$;
ROLLBACK;
