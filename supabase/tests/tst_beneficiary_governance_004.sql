-- TST-WP05/WP06 beneficiary governance contract tests.
BEGIN;
DO $$ DECLARE n int; BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='tst' AND c.relname IN ('beneficiaries','beneficiary_reviews','conflict_disclosures','recusals','independent_approvals') AND c.relrowsecurity;
 IF n<>5 THEN RAISE EXCEPTION 'beneficiary governance RLS incomplete: %/5',n; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='tst' AND table_name IN ('beneficiaries','beneficiary_reviews','conflict_disclosures','recusals','independent_approvals') AND grantee IN ('anon','authenticated')) THEN RAISE EXCEPTION 'client grant leak'; END IF;
END $$;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state) VALUES
('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','TST Beneficiary Test Org','tst beneficiary test org','FOUNDATION','VERIFIED') ON CONFLICT(oid) DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from) VALUES
('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','TST-BEN','TST Beneficiary Test Org','ACTIVE','2026-08-23') ON CONFLICT(organization_oid) DO NOTHING;

DO $$ DECLARE e uuid; b uuid; rp uuid; cp uuid; c uuid; BEGIN
 SELECT stewardship_entity_id INTO e FROM tst.stewardship_entities WHERE stewardship_code='TST-BEN';
 INSERT INTO tst.participants(stewardship_entity_id,organization_oid,auth_user_id,display_name,status) VALUES
 (e,'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','55555555-5555-5555-5555-555555555555','Independent Trustee','ACTIVE'),
 (e,'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','66666666-6666-6666-6666-666666666666','Conflicted Trustee','ACTIVE');
 SELECT participant_id INTO rp FROM tst.participants WHERE auth_user_id='55555555-5555-5555-5555-555555555555';
 SELECT participant_id INTO cp FROM tst.participants WHERE auth_user_id='66666666-6666-6666-6666-666666666666';
 INSERT INTO tst.beneficiaries(stewardship_entity_id,beneficiary_type,display_name,risk_tier,eligibility_status,compliance_status,conflict_status,related_party,next_review_date)
 VALUES(e,'INDIVIDUAL','Related Party Beneficiary','B1','ACTIVE','CLEAR','RESOLVED',true,'2027-08-23') RETURNING beneficiary_id INTO b;
 IF tst_private.beneficiary_is_distribution_eligible(b,'2026-08-23') THEN RAISE EXCEPTION 'related party eligible without independent approval'; END IF;
 INSERT INTO tst.conflict_disclosures(stewardship_entity_id,participant_id,beneficiary_id,relationship_type,description,status,recusal_required)
 VALUES(e,cp,b,'FAMILY','test conflict','RECUSAL_REQUIRED',true) RETURNING conflict_id INTO c;
 INSERT INTO tst.recusals(conflict_id,participant_id,scope,status) VALUES(c,cp,'ALL_BENEFICIARY_DECISIONS','ACTIVE');
 BEGIN
   INSERT INTO tst.independent_approvals(beneficiary_id,approver_participant_id,decision,authority_reference) VALUES(b,cp,'APPROVED','TEST');
   RAISE EXCEPTION 'conflicted approval unexpectedly accepted';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='conflicted approval unexpectedly accepted' THEN RAISE; END IF;
 END;
 INSERT INTO tst.independent_approvals(beneficiary_id,approver_participant_id,decision,authority_reference) VALUES(b,rp,'APPROVED','TEST-INDEPENDENT');
 IF NOT tst_private.beneficiary_is_distribution_eligible(b,'2026-08-23') THEN RAISE EXCEPTION 'valid independent approval did not clear beneficiary'; END IF;
 UPDATE tst.beneficiaries SET compliance_status='POTENTIAL_MATCH' WHERE beneficiary_id=b;
 IF tst_private.beneficiary_is_distribution_eligible(b,'2026-08-23') THEN RAISE EXCEPTION 'screening hold failed'; END IF;
 UPDATE tst.beneficiaries SET compliance_status='CLEAR',next_review_date='2026-08-22' WHERE beneficiary_id=b;
 IF tst_private.beneficiary_is_distribution_eligible(b,'2026-08-23') THEN RAISE EXCEPTION 'overdue review failed to block'; END IF;
END $$;
ROLLBACK;
