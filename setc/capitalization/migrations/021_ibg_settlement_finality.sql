-- IBG-06 Settlement Reconciliation & Finality Control Plane
-- External evidence + governed reconciliation are required. Internal/provider status alone is never settlement finality.
BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.settlement_observations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), observation_reference text NOT NULL UNIQUE,
 payment_instruction_id uuid REFERENCES capitalization.payment_instructions(id) ON DELETE RESTRICT,
 trade_finance_claim_id uuid REFERENCES capitalization.trade_finance_claims(id) ON DELETE RESTRICT,
 institution_id uuid REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
 external_reference text NOT NULL, source_type text NOT NULL, amount numeric(38,12) NOT NULL CHECK(amount>0), asset_code text NOT NULL,
 value_date date, counterparty_reference text, observation_status text NOT NULL DEFAULT 'OBSERVED', evidence_reference text NOT NULL,
 evidence_hash text, observed_at timestamptz NOT NULL, recorded_by_actor text NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT settlement_source_type_chk CHECK(source_type IN ('BANK_STATEMENT','BANK_API','PAYMENT_PROVIDER','CORRESPONDENT','CUSTODIAN','CLEARING_RAIL','MANUAL_VERIFIED_EXTERNAL','OTHER_EXTERNAL')),
 CONSTRAINT settlement_observation_status_chk CHECK(observation_status IN ('OBSERVED','RETURNED','REVERSED','REJECTED')),
 CONSTRAINT settlement_external_evidence_chk CHECK(length(btrim(external_reference))>0 AND length(btrim(evidence_reference))>0)
);
CREATE UNIQUE INDEX IF NOT EXISTS settlement_observation_dedupe_idx ON capitalization.settlement_observations(source_type,institution_id,external_reference,amount,asset_code,observed_at);

CREATE TABLE IF NOT EXISTS capitalization.settlement_matches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), observation_id uuid NOT NULL REFERENCES capitalization.settlement_observations(id) ON DELETE RESTRICT,
 payment_instruction_id uuid NOT NULL REFERENCES capitalization.payment_instructions(id) ON DELETE RESTRICT,
 match_status text NOT NULL DEFAULT 'PROPOSED', match_method text NOT NULL, amount_matches boolean NOT NULL DEFAULT false,
 asset_matches boolean NOT NULL DEFAULT false, value_date_matches boolean, counterparty_matches boolean, match_score numeric(6,5),
 matched_by_actor text NOT NULL, matched_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(observation_id,payment_instruction_id),
 CONSTRAINT settlement_match_status_chk CHECK(match_status IN ('PROPOSED','MATCHED','REJECTED','DUPLICATE','MANUAL_REVIEW')),
 CONSTRAINT settlement_match_method_chk CHECK(match_method IN ('EXTERNAL_REFERENCE','PROVIDER_REFERENCE','DETERMINISTIC_FIELDS','MANUAL_REVIEW')),
 CONSTRAINT settlement_match_score_chk CHECK(match_score IS NULL OR (match_score>=0 AND match_score<=1))
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_reconciliations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reconciliation_reference text NOT NULL UNIQUE,
 observation_id uuid NOT NULL REFERENCES capitalization.settlement_observations(id) ON DELETE RESTRICT,
 settlement_match_id uuid NOT NULL REFERENCES capitalization.settlement_matches(id) ON DELETE RESTRICT,
 reconciliation_status text NOT NULL DEFAULT 'MATCHED', reconciled_amount numeric(38,12) NOT NULL CHECK(reconciled_amount>0), asset_code text NOT NULL,
 value_date date, exception_count integer NOT NULL DEFAULT 0 CHECK(exception_count>=0), reconciled_by_actor text NOT NULL,
 reconciled_at timestamptz NOT NULL DEFAULT now(), evidence_reference text NOT NULL,
 CONSTRAINT settlement_reconciliation_status_chk CHECK(reconciliation_status IN ('MATCHED','PARTIAL','RECONCILED','FINALITY_PENDING','FINAL','DISPUTED','DUPLICATE','RETURNED','REVERSED','REJECTED','MANUAL_REVIEW'))
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reconciliation_id uuid NOT NULL REFERENCES capitalization.settlement_reconciliations(id) ON DELETE RESTRICT,
 approval_role text NOT NULL, approver_actor text NOT NULL, decision text NOT NULL, evidence_reference text, decided_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(reconciliation_id,approval_role,approver_actor),
 CONSTRAINT settlement_approval_role_chk CHECK(approval_role IN ('RECONCILIATION_CHECKER','FINALITY_CHECKER','TREASURY','COMPLIANCE','GOVERNANCE','OTHER')),
 CONSTRAINT settlement_approval_decision_chk CHECK(decision IN ('APPROVED','REJECTED','REVOKED'))
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_exceptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reconciliation_id uuid REFERENCES capitalization.settlement_reconciliations(id) ON DELETE RESTRICT,
 observation_id uuid REFERENCES capitalization.settlement_observations(id) ON DELETE RESTRICT,
 exception_type text NOT NULL, exception_status text NOT NULL DEFAULT 'OPEN', description text NOT NULL,
 resolution_evidence_reference text, opened_by_actor text NOT NULL, opened_at timestamptz NOT NULL DEFAULT now(), resolved_by_actor text, resolved_at timestamptz,
 CONSTRAINT settlement_exception_scope_chk CHECK(reconciliation_id IS NOT NULL OR observation_id IS NOT NULL),
 CONSTRAINT settlement_exception_type_chk CHECK(exception_type IN ('AMOUNT_MISMATCH','ASSET_MISMATCH','VALUE_DATE_MISMATCH','COUNTERPARTY_MISMATCH','UNMATCHED','PARTIAL','DUPLICATE','CONFLICTING_EVIDENCE','RETURN','REVERSAL','OTHER')),
 CONSTRAINT settlement_exception_status_chk CHECK(exception_status IN ('OPEN','UNDER_REVIEW','RESOLVED','WAIVED','REJECTED')),
 CONSTRAINT settlement_exception_resolution_chk CHECK(exception_status NOT IN ('RESOLVED','WAIVED') OR (resolution_evidence_reference IS NOT NULL AND resolved_by_actor IS NOT NULL AND resolved_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.settlement_finality_events (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, reconciliation_id uuid NOT NULL REFERENCES capitalization.settlement_reconciliations(id) ON DELETE RESTRICT,
 event_type text NOT NULL, prior_status text, new_status text NOT NULL, external_reference text NOT NULL, evidence_reference text NOT NULL,
 event_by_actor text NOT NULL, event_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT settlement_finality_event_type_chk CHECK(event_type IN ('RECONCILED','FINALITY_APPROVED','FINAL','RETURNED','REVERSED','EXCEPTION','REJECTED'))
);

CREATE OR REPLACE FUNCTION capitalization.validate_settlement_reconciliation()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
DECLARE o record; m record; p record; approvals integer; open_ex integer; BEGIN
 SELECT * INTO o FROM capitalization.settlement_observations WHERE id=NEW.observation_id;
 SELECT * INTO m FROM capitalization.settlement_matches WHERE id=NEW.settlement_match_id;
 IF m.observation_id IS DISTINCT FROM NEW.observation_id THEN RAISE EXCEPTION 'settlement match/observation mismatch' USING ERRCODE='23514'; END IF;
 SELECT * INTO p FROM capitalization.payment_instructions WHERE id=m.payment_instruction_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'payment instruction required' USING ERRCODE='23514'; END IF;
 IF NEW.reconciliation_status IN ('RECONCILED','FINALITY_PENDING','FINAL') THEN
  IF m.match_status<>'MATCHED' OR NOT m.amount_matches OR NOT m.asset_matches THEN RAISE EXCEPTION 'reconciliation requires deterministic amount/asset match' USING ERRCODE='23514'; END IF;
  IF NEW.reconciled_amount<>o.amount OR NEW.asset_code<>o.asset_code OR NEW.reconciled_amount<>p.amount OR NEW.asset_code<>p.asset_code THEN RAISE EXCEPTION 'reconciled amount/asset must equal external observation and payment instruction' USING ERRCODE='23514'; END IF;
  IF p.payment_state<>'COMPLETED' THEN RAISE EXCEPTION 'reconciliation finality requires IBG-03 provider completion first' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.reconciliation_status='FINAL' THEN
  SELECT count(*) INTO approvals FROM capitalization.settlement_approvals a WHERE a.reconciliation_id=NEW.id AND a.decision='APPROVED' AND a.approval_role IN ('RECONCILIATION_CHECKER','FINALITY_CHECKER');
  SELECT count(*) INTO open_ex FROM capitalization.settlement_exceptions e WHERE e.reconciliation_id=NEW.id AND e.exception_status IN ('OPEN','UNDER_REVIEW');
  IF approvals<2 THEN RAISE EXCEPTION 'FINAL requires reconciliation and finality checker approvals' USING ERRCODE='23514'; END IF;
  IF open_ex>0 OR NEW.exception_count>0 THEN RAISE EXCEPTION 'FINAL prohibited while exceptions remain' USING ERRCODE='23514'; END IF;
  IF o.observation_status<>'OBSERVED' THEN RAISE EXCEPTION 'returned/reversed/rejected observation cannot become FINAL' USING ERRCODE='23514'; END IF;
 END IF; RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION capitalization.validate_settlement_transition()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$ BEGIN
 IF OLD.reconciliation_status IS DISTINCT FROM NEW.reconciliation_status THEN
  IF OLD.reconciliation_status IN ('RETURNED','REVERSED','REJECTED') THEN RAISE EXCEPTION 'terminal exception state cannot transition' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.reconciliation_status='MATCHED' AND NEW.reconciliation_status IN ('PARTIAL','RECONCILED','DISPUTED','DUPLICATE','MANUAL_REVIEW','REJECTED')) OR
   (OLD.reconciliation_status='PARTIAL' AND NEW.reconciliation_status IN ('RECONCILED','DISPUTED','MANUAL_REVIEW','REJECTED')) OR
   (OLD.reconciliation_status='RECONCILED' AND NEW.reconciliation_status IN ('FINALITY_PENDING','RETURNED','REVERSED','DISPUTED')) OR
   (OLD.reconciliation_status='FINALITY_PENDING' AND NEW.reconciliation_status IN ('FINAL','RETURNED','REVERSED','DISPUTED','REJECTED')) OR
   (OLD.reconciliation_status='FINAL' AND NEW.reconciliation_status IN ('RETURNED','REVERSED')) OR
   (OLD.reconciliation_status IN ('DISPUTED','MANUAL_REVIEW','DUPLICATE') AND NEW.reconciliation_status IN ('MATCHED','RECONCILED','REJECTED'))) THEN RAISE EXCEPTION 'invalid settlement transition: % -> %',OLD.reconciliation_status,NEW.reconciliation_status USING ERRCODE='23514'; END IF;
 END IF; RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION capitalization.capture_settlement_finality_event()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
DECLARE o record; et text; BEGIN IF OLD.reconciliation_status IS DISTINCT FROM NEW.reconciliation_status THEN
 SELECT * INTO o FROM capitalization.settlement_observations WHERE id=NEW.observation_id;
 et:=CASE NEW.reconciliation_status WHEN 'RECONCILED' THEN 'RECONCILED' WHEN 'FINAL' THEN 'FINAL' WHEN 'RETURNED' THEN 'RETURNED' WHEN 'REVERSED' THEN 'REVERSED' WHEN 'REJECTED' THEN 'REJECTED' ELSE 'EXCEPTION' END;
 INSERT INTO capitalization.settlement_finality_events(reconciliation_id,event_type,prior_status,new_status,external_reference,evidence_reference,event_by_actor)
 VALUES(NEW.id,et,OLD.reconciliation_status,NEW.reconciliation_status,o.external_reference,NEW.evidence_reference,NEW.reconciled_by_actor); END IF; RETURN NEW; END; $$;

CREATE TRIGGER capitalization_settlement_transition BEFORE UPDATE ON capitalization.settlement_reconciliations FOR EACH ROW EXECUTE FUNCTION capitalization.validate_settlement_transition();
CREATE TRIGGER capitalization_settlement_validation BEFORE INSERT OR UPDATE ON capitalization.settlement_reconciliations FOR EACH ROW EXECUTE FUNCTION capitalization.validate_settlement_reconciliation();
CREATE TRIGGER capitalization_settlement_history AFTER UPDATE ON capitalization.settlement_reconciliations FOR EACH ROW EXECUTE FUNCTION capitalization.capture_settlement_finality_event();
CREATE TRIGGER capitalization_settlement_observation_append_only BEFORE UPDATE OR DELETE ON capitalization.settlement_observations FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();
CREATE TRIGGER capitalization_settlement_approval_append_only BEFORE UPDATE OR DELETE ON capitalization.settlement_approvals FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();
CREATE TRIGGER capitalization_settlement_finality_append_only BEFORE UPDATE OR DELETE ON capitalization.settlement_finality_events FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['settlement_observations','settlement_matches','settlement_reconciliations','settlement_approvals','settlement_exceptions','settlement_finality_events'] LOOP EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('REVOKE ALL ON capitalization.%I FROM PUBLIC, anon, authenticated',t); EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.%I TO service_role',t); END LOOP; END $$;
REVOKE UPDATE,DELETE ON capitalization.settlement_observations FROM service_role;
REVOKE UPDATE,DELETE ON capitalization.settlement_approvals FROM service_role;
REVOKE UPDATE,DELETE ON capitalization.settlement_finality_events FROM service_role;

CREATE OR REPLACE VIEW capitalization_api.settlement_finality AS
SELECT p.payment_reference,p.payment_state AS provider_payment_state,r.reconciliation_reference,r.reconciliation_status,
 o.external_reference,o.source_type,o.amount,o.asset_code,o.value_date,o.observed_at,r.reconciled_at,
 CASE WHEN r.reconciliation_status='FINAL' THEN true ELSE false END AS externally_reconciled_final,
 'IBG-06 finality is a governed classification based on retained external evidence and reconciliation. It does not create money, alter a bank ledger, or substitute for the external institution or rail record.'::text disclosure
FROM capitalization.settlement_reconciliations r JOIN capitalization.settlement_matches m ON m.id=r.settlement_match_id
JOIN capitalization.settlement_observations o ON o.id=r.observation_id JOIN capitalization.payment_instructions p ON p.id=m.payment_instruction_id;
REVOKE ALL ON capitalization_api.settlement_finality FROM PUBLIC,anon; GRANT SELECT ON capitalization_api.settlement_finality TO authenticated,service_role;

COMMENT ON TABLE capitalization.settlement_observations IS 'Append-only external settlement evidence observations. Internal dashboard/provider completion alone is insufficient.';
COMMENT ON TABLE capitalization.settlement_finality_events IS 'Immutable finality/return/reversal provenance. FINAL is a governed evidence classification, not authority over an external bank ledger.';
COMMIT;
