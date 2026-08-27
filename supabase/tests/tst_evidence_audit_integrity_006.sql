BEGIN;
DO $$ DECLARE c integer; BEGIN
 SELECT count(*) INTO c FROM pg_class x JOIN pg_namespace n ON n.oid=x.relnamespace WHERE n.nspname='tst' AND x.relname IN ('evidence_records','evidence_links','audit_events') AND x.relrowsecurity;
 IF c<>3 THEN RAISE EXCEPTION 'WP09/10 RLS incomplete'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='tst' AND table_name IN ('evidence_records','evidence_links','audit_events') AND grantee IN ('anon','authenticated')) THEN RAISE EXCEPTION 'client grant leak'; END IF;
END $$;
INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state) VALUES('SETC-OID-cccccccccccccccccccccccccccccccc','TST Audit Test','tst audit test','FOUNDATION','VERIFIED') ON CONFLICT DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from) VALUES('SETC-OID-cccccccccccccccccccccccccccccccc','TST-AUDIT','TST Audit Test','ACTIVE','2026-08-23') ON CONFLICT DO NOTHING;
DO $$ DECLARE e uuid; ev uuid; BEGIN
 SELECT stewardship_entity_id INTO e FROM tst.stewardship_entities WHERE stewardship_code='TST-AUDIT';
 INSERT INTO tst.evidence_records(stewardship_entity_id,evidence_type,subject_type,storage_provider,storage_locator,content_sha256,media_type) VALUES(e,'DOCUMENT','TEST','TEST','vault/test-1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','application/pdf') RETURNING evidence_id INTO ev;
 INSERT INTO tst.evidence_links(evidence_id,object_type,object_id) VALUES(ev,'EVIDENCE_TEST',ev);
 PERFORM tst_private.append_audit_event(e,NULL,'EVIDENCE_CAPTURED','EVIDENCE',ev,NULL,jsonb_build_object('sha256','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'));
 PERFORM tst_private.append_audit_event(e,NULL,'EVIDENCE_LINKED','EVIDENCE',ev,NULL,jsonb_build_object('relationship','SUPPORTS'));
 IF NOT tst_private.verify_audit_chain(e) THEN RAISE EXCEPTION 'valid audit chain rejected'; END IF;
 BEGIN UPDATE tst.audit_events SET action_code='TAMPERED' WHERE stewardship_entity_id=e; RAISE EXCEPTION 'audit update unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='audit update unexpectedly allowed' THEN RAISE; END IF; END;
 BEGIN DELETE FROM tst.audit_events WHERE stewardship_entity_id=e; RAISE EXCEPTION 'audit delete unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='audit delete unexpectedly allowed' THEN RAISE; END IF; END;
 BEGIN UPDATE tst.evidence_records SET content_sha256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' WHERE evidence_id=ev; RAISE EXCEPTION 'evidence hash mutation unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='evidence hash mutation unexpectedly allowed' THEN RAISE; END IF; END;
END $$;
ROLLBACK;
