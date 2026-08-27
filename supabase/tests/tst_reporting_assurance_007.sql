-- TST-WP11/WP12 reporting and assurance contract.
BEGIN;
DO $$ DECLARE c integer; BEGIN
 SELECT count(*) INTO c FROM pg_class x JOIN pg_namespace n ON n.oid=x.relnamespace WHERE n.nspname='tst' AND x.relname IN ('reporting_periods','stewardship_statements','trustee_attestations','assurance_packages') AND x.relrowsecurity;
 IF c<>4 THEN RAISE EXCEPTION 'reporting RLS incomplete'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='tst' AND table_name IN ('reporting_periods','stewardship_statements','trustee_attestations','assurance_packages') AND grantee IN ('anon','authenticated')) THEN RAISE EXCEPTION 'client grant leak'; END IF;
END $$;
INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state) VALUES('SETC-OID-cccccccccccccccccccccccccccccccc','TST Assurance Org','tst assurance org','FOUNDATION','VERIFIED') ON CONFLICT DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from) VALUES('SETC-OID-cccccccccccccccccccccccccccccccc','TST-ASSURANCE','TST Assurance Org','ACTIVE','2026-08-23') ON CONFLICT DO NOTHING;
DO $$ DECLARE e uuid; trustee uuid; rp uuid; s uuid; ap uuid; payload jsonb:='{"funds":"balanced","reconciliations":"complete"}'::jsonb; h text; BEGIN
 SELECT stewardship_entity_id INTO e FROM tst.stewardship_entities WHERE stewardship_code='TST-ASSURANCE';
 INSERT INTO tst.participants(stewardship_entity_id,organization_oid,auth_user_id,display_name,status) VALUES(e,'SETC-OID-cccccccccccccccccccccccccccccccc','20000000-0000-0000-0000-000000000001','Assurance Trustee','ACTIVE') RETURNING participant_id INTO trustee;
 INSERT INTO tst.role_assignments(participant_id,stewardship_entity_id,organization_oid,role_code,status) VALUES(trustee,e,'SETC-OID-cccccccccccccccccccccccccccccccc','TST_TRUSTEE','ACTIVE');
 PERFORM tst_private.append_audit_event(e,trustee,'PERIOD_OPENED','reporting_period',NULL,NULL,'{}');
 INSERT INTO tst.reporting_periods(stewardship_entity_id,period_code,period_start,period_end,status) VALUES(e,'2026-Q3','2026-07-01','2026-09-30','PRE_CLOSE') RETURNING reporting_period_id INTO rp;
 h:=encode(digest(payload::text,'sha256'),'hex');
 INSERT INTO tst.stewardship_statements(reporting_period_id,statement_type,generated_by_participant_id,statement_payload,payload_sha256,status) VALUES(rp,'TRUSTEE_STEWARDSHIP',trustee,payload,h,'FINAL') RETURNING statement_id INTO s;
 INSERT INTO tst.trustee_attestations(statement_id,trustee_participant_id,attestation_code,decision) VALUES(s,trustee,'TST-PERIOD-ATTEST','ATTESTED');
 IF NOT tst_private.period_assurance_ready(rp) THEN RAISE EXCEPTION 'period should be assurance ready'; END IF;
 BEGIN UPDATE tst.stewardship_statements SET statement_payload='{}' WHERE statement_id=s; RAISE EXCEPTION 'final statement mutation unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='final statement mutation unexpectedly allowed' THEN RAISE; END IF; END;
 INSERT INTO tst.assurance_packages(reporting_period_id,package_code,manifest,manifest_sha256,evidence_complete,audit_chain_verified,reconciliation_complete,trustee_attested,status) VALUES(rp,'AP-2026-Q3','{}',repeat('a',64),true,true,true,true,'READY') RETURNING assurance_package_id INTO ap;
 PERFORM tst_private.issue_assurance_package(ap,trustee);
 IF (SELECT status FROM tst.assurance_packages WHERE assurance_package_id=ap)<>'ISSUED' THEN RAISE EXCEPTION 'package not issued'; END IF;
 IF (SELECT status FROM tst.reporting_periods WHERE reporting_period_id=rp)<>'CLOSED' THEN RAISE EXCEPTION 'period not closed'; END IF;
 IF NOT tst_private.verify_audit_chain(e) THEN RAISE EXCEPTION 'audit chain invalid after issuance'; END IF;
END $$;
ROLLBACK;
