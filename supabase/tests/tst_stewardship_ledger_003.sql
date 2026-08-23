BEGIN;
DO $$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='tst' AND c.relname IN ('funds','tithe_elections','tithe_calculations','contributions','allocations') AND c.relrowsecurity;
 IF n<>5 THEN RAISE EXCEPTION 'ledger RLS incomplete %/5',n; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='tst' AND table_name IN ('funds','tithe_elections','tithe_calculations','contributions','allocations') AND grantee IN ('anon','authenticated')) THEN RAISE EXCEPTION 'client ledger grants found'; END IF;
END $$;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES('SETC-OID-dddddddddddddddddddddddddddddddd','TST Ledger Org','tst ledger org','FOUNDATION','VERIFIED') ON CONFLICT DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from)
VALUES('SETC-OID-dddddddddddddddddddddddddddddddd','TST-LEDGER','TST Ledger Org','ACTIVE','2026-08-23') ON CONFLICT(organization_oid) DO NOTHING;

DO $$ DECLARE eid uuid; elid uuid; fid uuid; cid uuid; amt numeric; avail numeric; BEGIN
 SELECT stewardship_entity_id INTO eid FROM tst.stewardship_entities WHERE stewardship_code='TST-LEDGER';
 INSERT INTO tst.funds(stewardship_entity_id,fund_code,fund_name,restriction_type,currency) VALUES(eid,'TITHE','Tithe Stewardship Fund','PURPOSE_RESTRICTED','USD') RETURNING fund_id INTO fid;
 INSERT INTO tst.tithe_elections(stewardship_entity_id,organization_oid,rate,basis_code,currency,status,effective_from,approval_reference)
 VALUES(eid,'SETC-OID-dddddddddddddddddddddddddddddddd',0.10,'ELIGIBLE_BASE','USD','ACTIVE','2026-08-01','TEST-APPROVAL') RETURNING election_id INTO elid;
 cid:=tst_private.calculate_tithe(elid,'2026-08-01','2026-08-31',1234.567890);
 SELECT calculated_amount INTO amt FROM tst.tithe_calculations WHERE calculation_id=cid;
 IF amt<>123.456789 THEN RAISE EXCEPTION 'server calculation wrong: %',amt; END IF;
 INSERT INTO tst.contributions(calculation_id,fund_id,amount,currency,status,received_at) VALUES(cid,fid,amt,'USD','RECEIVED',now());
 SELECT tst_private.fund_available_balance(fid) INTO avail;
 IF avail<>123.456789 THEN RAISE EXCEPTION 'available balance wrong: %',avail; END IF;
 INSERT INTO tst.allocations(fund_id,allocation_code,purpose,authorized_amount,committed_amount,currency,status) VALUES(fid,'A1','Pilot beneficiary allocation',100,50,'USD','ACTIVE');
 SELECT tst_private.fund_available_balance(fid) INTO avail;
 IF avail<>73.456789 THEN RAISE EXCEPTION 'commitment not reflected: %',avail; END IF;
 BEGIN
   INSERT INTO tst.allocations(fund_id,allocation_code,purpose,authorized_amount,committed_amount,currency,status) VALUES(fid,'A2','Overspend test',100,80,'USD','ACTIVE');
   RAISE EXCEPTION 'overspend unexpectedly accepted';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='overspend unexpectedly accepted' THEN RAISE; END IF;
 END;
END $$;

DO $$ BEGIN
 BEGIN
   PERFORM tst_private.calculate_tithe((SELECT election_id FROM tst.tithe_elections LIMIT 1),'2026-09-02','2026-09-01',100);
   RAISE EXCEPTION 'invalid period unexpectedly accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='invalid period unexpectedly accepted' THEN RAISE; END IF; END;
END $$;
ROLLBACK;
