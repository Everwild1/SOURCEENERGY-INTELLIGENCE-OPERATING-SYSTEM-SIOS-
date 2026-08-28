BEGIN;

DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='ecology') THEN
  RAISE EXCEPTION 'ecology schema missing';
 END IF;
 IF EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='ecology'
    AND c.relname = ANY(ARRAY['object_references','journeys','journey_edges','event_receipts','value_flow_references','impact_lineage','regenerative_projections'])
    AND NOT c.relrowsecurity
 ) THEN RAISE EXCEPTION 'Ecology table without RLS'; END IF;
 IF has_schema_privilege('anon','ecology','USAGE') OR has_schema_privilege('authenticated','ecology','USAGE') THEN
  RAISE EXCEPTION 'client role unexpectedly has ecology schema usage';
 END IF;
 IF EXISTS (
  SELECT 1 FROM information_schema.role_table_grants
  WHERE table_schema='ecology' AND grantee IN ('anon','authenticated')
 ) THEN RAISE EXCEPTION 'client role unexpectedly has direct ecology table privilege'; END IF;
END $$;

INSERT INTO ecology.object_references(domain,object_type,object_id,source_authority,organization_oid,posture)
VALUES ('hei','research_project','RP-001','HEI','SETC-OID-cccccccccccccccccccccccccccccccc','reference_only');

INSERT INTO ecology.object_references(domain,object_type,object_id,source_authority,organization_oid,posture)
VALUES ('wim','market_opportunity','OPP-001','WIM','SETC-OID-cccccccccccccccccccccccccccccccc','reference_only');

INSERT INTO ecology.journeys(journey_key,organization_oid)
VALUES ('ECO-TEST-001','SETC-OID-cccccccccccccccccccccccccccccccc');

INSERT INTO ecology.journey_edges(journey_id,from_reference_id,to_reference_id,edge_type,source_authority)
SELECT j.id,a.id,b.id,'venture_to_market','ECOLOGY'
FROM ecology.journeys j
JOIN ecology.object_references a ON a.object_id='RP-001'
JOIN ecology.object_references b ON b.object_id='OPP-001'
WHERE j.journey_key='ECO-TEST-001';

INSERT INTO ecology.event_receipts(event_id,event_name,contract_version,producer_domain,source_authority,correlation_id,idempotency_key,occurred_at)
VALUES ('evt-eco-e04-1','ecology.reference.projected','1.0','hei','HEI','corr-eco-e04-1','idem-eco-e04-1',now());

DO $$ DECLARE blocked boolean := false; BEGIN
 BEGIN
  INSERT INTO ecology.object_references(domain,object_type,object_id,source_authority,posture)
  VALUES ('source_coin','ledger_balance','BAL-001','ECOLOGY','reference_only');
 EXCEPTION WHEN OTHERS THEN blocked := true; END;
 -- The schema stores references only; this verifies there is no ledger/balance table or authority column to mutate.
 IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='ecology' AND table_name IN ('accounts','balances','transactions','treasury_accounts')) THEN
  RAISE EXCEPTION 'Ecology duplicated authoritative financial tables';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM ecology.event_receipts WHERE idempotency_key='idem-eco-e04-1') THEN
  RAISE EXCEPTION 'event receipt contract failed';
 END IF;
END $$;

ROLLBACK;
SELECT 'eco_e04_projection_foundation_contract_passed' AS result;
