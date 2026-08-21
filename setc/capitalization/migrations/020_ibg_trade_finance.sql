-- IBG-05 Trade Finance Control Plane
-- Governance registry only. No record here creates a bank undertaking, available credit, payment authority, or settlement finality.
BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_instruments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_reference text NOT NULL UNIQUE,
 instrument_type text NOT NULL, instrument_state text NOT NULL DEFAULT 'DRAFT', amount numeric(38,12) NOT NULL CHECK(amount>0), asset_code text NOT NULL,
 applicant_reference text NOT NULL, beneficiary_reference text NOT NULL,
 issuing_institution_id uuid REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
 advising_institution_id uuid REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
 confirming_institution_id uuid REFERENCES capitalization.financial_institutions(id) ON DELETE RESTRICT,
 collateral_account_id uuid REFERENCES capitalization.treasury_accounts(id) ON DELETE RESTRICT,
 governing_rules text, governing_jurisdiction text, issue_date date, expiry_date date NOT NULL,
 evidence_reference text, external_instrument_reference text, compliance_status text NOT NULL DEFAULT 'PENDING',
 requested_by_actor text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT tf_type_chk CHECK(instrument_type IN ('LETTER_OF_CREDIT','STANDBY_LETTER_OF_CREDIT','BANK_GUARANTEE','DOCUMENTARY_COLLECTION','SUPPLY_CHAIN_FINANCE','OTHER')),
 CONSTRAINT tf_state_chk CHECK(instrument_state IN ('DRAFT','PENDING_APPROVAL','APPROVED','ISSUED','ADVISED','CONFIRMED','ACTIVE','PRESENTED','DISCREPANT','HONOURED','REFUSED','CANCELLED','EXPIRED','CLOSED')),
 CONSTRAINT tf_compliance_chk CHECK(compliance_status IN ('PENDING','CLEAR','REVIEW','ON_HOLD','REJECTED')),
 CONSTRAINT tf_dates_chk CHECK(issue_date IS NULL OR expiry_date>=issue_date)
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 approver_actor text NOT NULL, approval_role text NOT NULL, decision text NOT NULL, evidence_reference text, reason text, decided_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(instrument_id,approver_actor,approval_role),
 CONSTRAINT tf_approval_role_chk CHECK(approval_role IN ('MAKER_REVIEW','CHECKER','COMPLIANCE','TREASURY','GOVERNANCE','LEGAL','OTHER')),
 CONSTRAINT tf_approval_decision_chk CHECK(decision IN ('APPROVED','REJECTED','REVOKED'))
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 document_type text NOT NULL, requirement_status text NOT NULL DEFAULT 'REQUIRED', presentation_status text NOT NULL DEFAULT 'NOT_PRESENTED',
 document_reference text, evidence_reference text, presented_at timestamptz, reviewed_at timestamptz, reviewed_by_actor text,
 CONSTRAINT tf_document_requirement_chk CHECK(requirement_status IN ('REQUIRED','OPTIONAL','WAIVED')),
 CONSTRAINT tf_document_presentation_chk CHECK(presentation_status IN ('NOT_PRESENTED','PRESENTED','ACCEPTED','DISCREPANT','REJECTED','WAIVED')),
 CONSTRAINT tf_document_evidence_chk CHECK(presentation_status='NOT_PRESENTED' OR presentation_status='WAIVED' OR evidence_reference IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_discrepancies (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 document_id uuid REFERENCES capitalization.trade_finance_documents(id) ON DELETE RESTRICT, discrepancy_code text, description text NOT NULL,
 discrepancy_status text NOT NULL DEFAULT 'OPEN', waiver_evidence_reference text, decided_by_actor text, decided_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT tf_discrepancy_status_chk CHECK(discrepancy_status IN ('OPEN','CURED','WAIVED','REJECTED')),
 CONSTRAINT tf_discrepancy_waiver_chk CHECK(discrepancy_status<>'WAIVED' OR (waiver_evidence_reference IS NOT NULL AND decided_by_actor IS NOT NULL AND decided_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_exposures (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 exposure_type text NOT NULL, amount numeric(38,12) NOT NULL CHECK(amount>=0), asset_code text NOT NULL,
 treasury_limit_id uuid REFERENCES capitalization.treasury_limits(id) ON DELETE RESTRICT,
 liquidity_reservation_id uuid REFERENCES capitalization.liquidity_reservations(id) ON DELETE RESTRICT,
 evidence_reference text NOT NULL, observed_at timestamptz NOT NULL,
 CONSTRAINT tf_exposure_type_chk CHECK(exposure_type IN ('FACILITY','COLLATERAL','MARGIN','CONTINGENT','DRAWN','CLAIM','OTHER'))
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_claims (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 claim_reference text NOT NULL UNIQUE, claim_amount numeric(38,12) NOT NULL CHECK(claim_amount>0), asset_code text NOT NULL,
 claim_status text NOT NULL DEFAULT 'DRAFT', payment_instruction_id uuid REFERENCES capitalization.payment_instructions(id) ON DELETE RESTRICT,
 evidence_reference text, created_by_actor text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT tf_claim_status_chk CHECK(claim_status IN ('DRAFT','PRESENTED','ACCEPTED','DISPUTED','REJECTED','PAYMENT_REQUESTED','CLOSED')),
 CONSTRAINT tf_claim_payment_chk CHECK(claim_status<>'PAYMENT_REQUESTED' OR payment_instruction_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS capitalization.trade_finance_state_history (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, instrument_id uuid NOT NULL REFERENCES capitalization.trade_finance_instruments(id) ON DELETE RESTRICT,
 prior_state text, new_state text NOT NULL, prior_record jsonb NOT NULL, new_record jsonb NOT NULL, changed_by_actor text, changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION capitalization.validate_trade_finance_instrument()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
DECLARE r text; v text; o text; approvals integer; BEGIN
 IF NEW.instrument_state IN ('APPROVED','ISSUED','ADVISED','CONFIRMED','ACTIVE','PRESENTED','DISCREPANT','HONOURED') THEN
  SELECT count(*) INTO approvals FROM capitalization.trade_finance_approvals a WHERE a.instrument_id=NEW.id AND a.decision='APPROVED';
  IF approvals<2 THEN RAISE EXCEPTION 'trade finance instrument requires at least two approvals' USING ERRCODE='23514'; END IF;
  IF NEW.compliance_status<>'CLEAR' THEN RAISE EXCEPTION 'trade finance instrument requires CLEAR compliance status' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.instrument_state IN ('ISSUED','ADVISED','CONFIRMED','ACTIVE','PRESENTED','DISCREPANT','HONOURED') THEN
  IF NEW.evidence_reference IS NULL OR NEW.external_instrument_reference IS NULL THEN RAISE EXCEPTION 'external instrument states require authoritative evidence and external reference' USING ERRCODE='23514'; END IF;
  IF NEW.issuing_institution_id IS NULL THEN RAISE EXCEPTION 'issued instrument requires issuing institution' USING ERRCODE='23514'; END IF;
  SELECT verification_status,operating_status INTO v,o FROM capitalization.financial_institutions WHERE id=NEW.issuing_institution_id;
  IF v IS DISTINCT FROM 'VERIFIED' OR o NOT IN ('APPROVED','ACTIVE') THEN RAISE EXCEPTION 'issuing institution must be VERIFIED and approved/active' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.instrument_state IN ('CONFIRMED','ACTIVE') AND NEW.confirming_institution_id IS NOT NULL THEN
  SELECT verification_status,operating_status INTO v,o FROM capitalization.financial_institutions WHERE id=NEW.confirming_institution_id;
  IF v IS DISTINCT FROM 'VERIFIED' OR o NOT IN ('APPROVED','ACTIVE') THEN RAISE EXCEPTION 'confirming institution must be VERIFIED and approved/active' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.collateral_account_id IS NOT NULL AND NEW.instrument_state IN ('ISSUED','CONFIRMED','ACTIVE') THEN
  SELECT operational_eligibility INTO r FROM capitalization.treasury_accounts WHERE id=NEW.collateral_account_id;
  IF r IS DISTINCT FROM 'PRODUCTION_ELIGIBLE' THEN RAISE EXCEPTION 'collateral account must be production eligible' USING ERRCODE='23514'; END IF;
 END IF; RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION capitalization.validate_trade_finance_transition()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$ BEGIN
 IF OLD.instrument_state IS DISTINCT FROM NEW.instrument_state THEN
  IF OLD.instrument_state IN ('HONOURED','REFUSED','CANCELLED','EXPIRED','CLOSED') THEN RAISE EXCEPTION 'terminal trade-finance state cannot transition' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.instrument_state='DRAFT' AND NEW.instrument_state IN ('PENDING_APPROVAL','CANCELLED')) OR
   (OLD.instrument_state='PENDING_APPROVAL' AND NEW.instrument_state IN ('APPROVED','CANCELLED')) OR
   (OLD.instrument_state='APPROVED' AND NEW.instrument_state IN ('ISSUED','CANCELLED','EXPIRED')) OR
   (OLD.instrument_state='ISSUED' AND NEW.instrument_state IN ('ADVISED','CONFIRMED','ACTIVE','CANCELLED','EXPIRED')) OR
   (OLD.instrument_state='ADVISED' AND NEW.instrument_state IN ('CONFIRMED','ACTIVE','PRESENTED','CANCELLED','EXPIRED')) OR
   (OLD.instrument_state='CONFIRMED' AND NEW.instrument_state IN ('ACTIVE','PRESENTED','CANCELLED','EXPIRED')) OR
   (OLD.instrument_state='ACTIVE' AND NEW.instrument_state IN ('PRESENTED','CANCELLED','EXPIRED')) OR
   (OLD.instrument_state='PRESENTED' AND NEW.instrument_state IN ('DISCREPANT','HONOURED','REFUSED')) OR
   (OLD.instrument_state='DISCREPANT' AND NEW.instrument_state IN ('PRESENTED','HONOURED','REFUSED'))) THEN RAISE EXCEPTION 'invalid trade-finance state transition: % -> %',OLD.instrument_state,NEW.instrument_state USING ERRCODE='23514'; END IF;
 END IF; RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION capitalization.capture_trade_finance_history()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$ BEGIN
 IF OLD.instrument_state IS DISTINCT FROM NEW.instrument_state OR OLD.compliance_status IS DISTINCT FROM NEW.compliance_status THEN
  INSERT INTO capitalization.trade_finance_state_history(instrument_id,prior_state,new_state,prior_record,new_record,changed_by_actor)
  VALUES(NEW.id,OLD.instrument_state,NEW.instrument_state,to_jsonb(OLD),to_jsonb(NEW),NEW.requested_by_actor); END IF; RETURN NEW; END; $$;

CREATE TRIGGER capitalization_tf_updated_at BEFORE UPDATE ON capitalization.trade_finance_instruments FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();
CREATE TRIGGER capitalization_tf_transition BEFORE UPDATE ON capitalization.trade_finance_instruments FOR EACH ROW EXECUTE FUNCTION capitalization.validate_trade_finance_transition();
CREATE TRIGGER capitalization_tf_validation BEFORE INSERT OR UPDATE ON capitalization.trade_finance_instruments FOR EACH ROW EXECUTE FUNCTION capitalization.validate_trade_finance_instrument();
CREATE TRIGGER capitalization_tf_history AFTER UPDATE ON capitalization.trade_finance_instruments FOR EACH ROW EXECUTE FUNCTION capitalization.capture_trade_finance_history();
CREATE TRIGGER capitalization_tf_history_append_only BEFORE UPDATE OR DELETE ON capitalization.trade_finance_state_history FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();
CREATE TRIGGER capitalization_tf_approvals_append_only BEFORE UPDATE OR DELETE ON capitalization.trade_finance_approvals FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['trade_finance_instruments','trade_finance_approvals','trade_finance_documents','trade_finance_discrepancies','trade_finance_exposures','trade_finance_claims','trade_finance_state_history'] LOOP EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('REVOKE ALL ON capitalization.%I FROM PUBLIC, anon, authenticated',t); EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.%I TO service_role',t); END LOOP; END $$;
REVOKE UPDATE,DELETE ON capitalization.trade_finance_approvals FROM service_role;
REVOKE UPDATE,DELETE ON capitalization.trade_finance_state_history FROM service_role;

CREATE OR REPLACE VIEW capitalization_api.trade_finance AS
SELECT t.instrument_reference,t.instrument_type,t.instrument_state,t.amount,t.asset_code,t.expiry_date,t.compliance_status,
 fi.institution_reference issuing_institution_reference,cf.institution_reference confirming_institution_reference,
 t.external_instrument_reference,t.updated_at,
 'Governance registry state only. This projection does not independently prove authenticity, enforceability, available credit, collateral, bank undertaking, payment, or settlement finality.'::text disclosure
FROM capitalization.trade_finance_instruments t LEFT JOIN capitalization.financial_institutions fi ON fi.id=t.issuing_institution_id LEFT JOIN capitalization.financial_institutions cf ON cf.id=t.confirming_institution_id;
REVOKE ALL ON capitalization_api.trade_finance FROM PUBLIC,anon; GRANT SELECT ON capitalization_api.trade_finance TO authenticated,service_role;
COMMENT ON TABLE capitalization.trade_finance_instruments IS 'IBG-05 governed trade-finance registry; presence does not create or authenticate a bank undertaking.';
COMMENT ON TABLE capitalization.trade_finance_claims IS 'Claims may reference IBG-03 payment instructions but cannot execute payment directly.';
COMMIT;
