BEGIN;
DO $$ DECLARE c integer; BEGIN SELECT count(*) INTO c FROM pg_class x JOIN pg_namespace n ON n.oid=x.relnamespace WHERE n.nspname='tst' AND x.relname IN ('compliance_obligations','control_findings','remediation_actions','compliance_reviews') AND x.relrowsecurity; IF c<>4 THEN RAISE EXCEPTION 'oversight RLS incomplete'; END IF; END $$;
INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state) VALUES('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','TST Oversight Org','tst oversight org','FOUNDATION','VERIFIED') ON CONFLICT DO NOTHING;
INSERT INTO tst.stewardship_entities(organization_oid,stewardship_code,legal_name,status,effective_from) VALUES('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','TST-OVERSIGHT','TST Oversight Org','ACTIVE','2026-08-23') ON CONFLICT DO NOTHING;
DO $$ DECLARE e uuid; p uuid; ev uuid; f uuid; r uuid; BEGIN
 SELECT stewardship_entity_id INTO e FROM tst.stewardship_entities WHERE stewardship_code='TST-OVERSIGHT';
 INSERT INTO tst.participants(stewardship_entity_id,organization_oid,auth_user_id,display_name,status) VALUES(e,'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','30000000-0000-0000-0000-000000000001','Compliance Validator','ACTIVE') RETURNING participant_id INTO p;
 INSERT INTO tst.evidence_records(stewardship_entity_id,evidence_type,subject_type,storage_provider,storage_locator,content_sha256,captured_by_participant_id) VALUES(e,'REMEDIATION','CONTROL_FINDING','TEST','evidence://closure',repeat('b',64),p) RETURNING evidence_id INTO ev;
 INSERT INTO tst.control_findings(stewardship_entity_id,finding_code,severity,title,description,status,owner_participant_id) VALUES(e,'F-001','HIGH','Control exception','test','REMEDIATING',p) RETURNING finding_id INTO f;
 IF tst_private.entity_compliance_ready(e) THEN RAISE EXCEPTION 'entity unexpectedly ready with high finding'; END IF;
 BEGIN PERFORM tst_private.close_finding(f,p); RAISE EXCEPTION 'finding closed without remediation'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='finding closed without remediation' THEN RAISE; END IF; END;
 INSERT INTO tst.remediation_actions(finding_id,action_text,owner_participant_id,status,validated_by_participant_id,validated_at,closure_evidence_id) VALUES(f,'Correct control',p,'VALIDATED',p,now(),ev) RETURNING remediation_id INTO r;
 PERFORM tst_private.close_finding(f,p);
 IF NOT tst_private.entity_compliance_ready(e) THEN RAISE EXCEPTION 'entity should be compliance ready'; END IF;
 IF NOT tst_private.verify_audit_chain(e) THEN RAISE EXCEPTION 'audit chain invalid after closure'; END IF;
 INSERT INTO tst.compliance_obligations(stewardship_entity_id,obligation_code,title,authority_source,next_due_date,status) VALUES(e,'OB-001','Annual review','Internal Governance',current_date-1,'ACTIVE');
 IF tst_private.entity_compliance_ready(e) THEN RAISE EXCEPTION 'overdue obligation not blocking readiness'; END IF;
END $$;
ROLLBACK;
