-- IBG-08 SBLC Monetization & Private Placement Control Plane
-- Governance/evidence registry only. No row creates or authenticates a bank undertaking,
-- funding commitment, custody authority, trading return, payment, or settlement finality.
BEGIN;

CREATE TABLE IF NOT EXISTS capitalization.monetization_cases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_reference text NOT NULL UNIQUE,
 external_instrument_reference text NOT NULL,
 instrument_type text NOT NULL,
 submitted_amount numeric(38,12) CHECK(submitted_amount IS NULL OR submitted_amount>0),
 face_amount numeric(38,12) NOT NULL CHECK(face_amount>0),
 asset_code text NOT NULL,
 case_state text NOT NULL DEFAULT 'P0_UNSCREENED',
 instrument_recognition_status text NOT NULL DEFAULT 'EVIDENCE_RECEIVED',
 instrument_evidence_status text NOT NULL DEFAULT 'PARTIAL',
 independent_bank_authentication boolean NOT NULL DEFAULT false,
 deployable_cash numeric(38,12) NOT NULL DEFAULT 0 CHECK(deployable_cash>=0),
 realized_liquidity numeric(38,12) NOT NULL DEFAULT 0 CHECK(realized_liquidity>=0),
 requested_by_actor text NOT NULL,
 opened_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT monetization_case_state_chk CHECK(case_state IN ('P0_UNSCREENED','P1_INTAKE_RECEIVED','P2_VERIFIED_CANDIDATE','P3_TRANSACTION_QUALIFIED','P4_AUTHORIZED','PX_SUSPENDED_REJECTED')),
 CONSTRAINT monetization_instrument_type_chk CHECK(instrument_type IN ('STANDBY_LETTER_OF_CREDIT','LETTER_OF_CREDIT','BANK_GUARANTEE','OTHER'))
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_counterparties (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 counterparty_reference text NOT NULL,
 legal_name text NOT NULL,
 role_code text NOT NULL,
 jurisdiction_code text,
 registration_reference text,
 regulatory_basis text,
 beneficial_ownership_status text NOT NULL DEFAULT 'PENDING',
 sanctions_aml_status text NOT NULL DEFAULT 'PENDING',
 banking_verification_status text NOT NULL DEFAULT 'PENDING',
 capacity_verification_status text NOT NULL DEFAULT 'PENDING',
 status text NOT NULL DEFAULT 'CANDIDATE',
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(case_id,counterparty_reference,role_code),
 CONSTRAINT monetization_role_chk CHECK(role_code IN ('PLATFORM','MONETIZER','FUNDER','TRADER','MANDATE','INTERMEDIARY','CUSTODIAN','ESCROW','FEE_RECIPIENT','LEGAL','OTHER')),
 CONSTRAINT monetization_verification_chk CHECK(beneficial_ownership_status IN ('PENDING','VERIFIED','FAILED','NOT_APPLICABLE') AND sanctions_aml_status IN ('PENDING','CLEAR','REVIEW','FAILED') AND banking_verification_status IN ('PENDING','VERIFIED','FAILED','NOT_APPLICABLE') AND capacity_verification_status IN ('PENDING','VERIFIED','FAILED','NOT_APPLICABLE')),
 CONSTRAINT monetization_counterparty_status_chk CHECK(status IN ('CANDIDATE','UNDER_REVIEW','QUALIFIED','REJECTED','SUSPENDED'))
);

CREATE TABLE IF NOT EXISTS capitalization.platform_due_diligence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 counterparty_id uuid NOT NULL REFERENCES capitalization.monetization_counterparties(id) ON DELETE RESTRICT,
 diligence_type text NOT NULL,
 diligence_status text NOT NULL DEFAULT 'PENDING',
 evidence_reference text,
 independent_verifier text,
 verified_at timestamptz,
 expires_at timestamptz,
 notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(counterparty_id,diligence_type),
 CONSTRAINT platform_dd_type_chk CHECK(diligence_type IN ('LEGAL_IDENTITY','REGISTRATION','BENEFICIAL_OWNERSHIP','REGULATORY_BASIS','SANCTIONS_AML','BANKING_RELATIONSHIP','FUNDING_CAPACITY','CUSTODY_CAPACITY','TRACK_RECORD','FEE_SCHEDULE','DEFINITIVE_AGREEMENT','ADVERSE_MEDIA','OTHER')),
 CONSTRAINT platform_dd_status_chk CHECK(diligence_status IN ('PENDING','VERIFIED','CLEAR','REVIEW','FAILED','EXPIRED','NOT_APPLICABLE')),
 CONSTRAINT platform_dd_evidence_chk CHECK(diligence_status NOT IN ('VERIFIED','CLEAR') OR (evidence_reference IS NOT NULL AND independent_verifier IS NOT NULL AND verified_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.instrument_encumbrances (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 encumbrance_reference text NOT NULL UNIQUE,
 encumbrance_type text NOT NULL,
 counterparty_id uuid REFERENCES capitalization.monetization_counterparties(id) ON DELETE RESTRICT,
 amount numeric(38,12) CHECK(amount IS NULL OR amount>=0),
 asset_code text,
 status text NOT NULL DEFAULT 'PROPOSED',
 evidence_reference text,
 effective_at timestamptz,
 released_at timestamptz,
 release_evidence_reference text,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT encumbrance_type_chk CHECK(encumbrance_type IN ('PLEDGE','ASSIGNMENT','LIEN','COLLATERAL_USE','CUSTODY_CONTROL','BLOCK','OTHER')),
 CONSTRAINT encumbrance_status_chk CHECK(status IN ('PROPOSED','ACTIVE','RELEASE_PENDING','RELEASED','REJECTED')),
 CONSTRAINT encumbrance_active_evidence_chk CHECK(status<>'ACTIVE' OR (evidence_reference IS NOT NULL AND effective_at IS NOT NULL)),
 CONSTRAINT encumbrance_release_chk CHECK(status<>'RELEASED' OR (released_at IS NOT NULL AND release_evidence_reference IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_funding_facilities (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 facility_reference text NOT NULL UNIQUE,
 funder_counterparty_id uuid NOT NULL REFERENCES capitalization.monetization_counterparties(id) ON DELETE RESTRICT,
 proposed_amount numeric(38,12) NOT NULL CHECK(proposed_amount>0),
 verified_amount numeric(38,12) NOT NULL DEFAULT 0 CHECK(verified_amount>=0),
 asset_code text NOT NULL,
 facility_status text NOT NULL DEFAULT 'PROPOSED',
 funding_source_evidence_reference text,
 agreement_evidence_reference text,
 verified_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT monetization_facility_status_chk CHECK(facility_status IN ('PROPOSED','DUE_DILIGENCE','VERIFIED','APPROVED','FUNDED','REJECTED','CANCELLED','CLOSED')),
 CONSTRAINT monetization_facility_verified_chk CHECK(facility_status NOT IN ('VERIFIED','APPROVED','FUNDED') OR (verified_amount>0 AND funding_source_evidence_reference IS NOT NULL AND verified_at IS NOT NULL)),
 CONSTRAINT monetization_facility_funded_chk CHECK(facility_status<>'FUNDED' OR agreement_evidence_reference IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_economics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 economics_version integer NOT NULL DEFAULT 1 CHECK(economics_version>0),
 proposed_financing_amount numeric(38,12) CHECK(proposed_financing_amount IS NULL OR proposed_financing_amount>=0),
 verified_financing_amount numeric(38,12) NOT NULL DEFAULT 0 CHECK(verified_financing_amount>=0),
 transaction_costs numeric(38,12) NOT NULL DEFAULT 0 CHECK(transaction_costs>=0),
 reserves numeric(38,12) NOT NULL DEFAULT 0 CHECK(reserves>=0),
 projected_return numeric(38,12) NOT NULL DEFAULT 0 CHECK(projected_return>=0),
 realized_proceeds numeric(38,12) NOT NULL DEFAULT 0 CHECK(realized_proceeds>=0),
 net_deployable_capital numeric(38,12) NOT NULL DEFAULT 0 CHECK(net_deployable_capital>=0),
 asset_code text NOT NULL,
 economics_status text NOT NULL DEFAULT 'DRAFT',
 evidence_reference text,
 approved_by_actor text,
 approved_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(case_id,economics_version),
 CONSTRAINT monetization_economics_status_chk CHECK(economics_status IN ('DRAFT','SUBMITTED','VERIFIED','APPROVED','SUPERSEDED','REJECTED')),
 CONSTRAINT monetization_economics_approval_chk CHECK(economics_status<>'APPROVED' OR (evidence_reference IS NOT NULL AND approved_by_actor IS NOT NULL AND approved_at IS NOT NULL)),
 CONSTRAINT monetization_realized_boundary_chk CHECK(net_deployable_capital<=realized_proceeds)
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 evidence_type text NOT NULL,
 evidence_reference text NOT NULL,
 evidence_status text NOT NULL DEFAULT 'RECEIVED',
 source_authority text,
 independently_verified boolean NOT NULL DEFAULT false,
 received_at timestamptz NOT NULL DEFAULT now(),
 verified_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT monetization_evidence_status_chk CHECK(evidence_status IN ('RECEIVED','UNDER_REVIEW','VERIFIED','REJECTED','EXPIRED','SUPERSEDED')),
 CONSTRAINT monetization_evidence_verified_chk CHECK(evidence_status<>'VERIFIED' OR (independently_verified=true AND source_authority IS NOT NULL AND verified_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 approval_role text NOT NULL,
 approver_actor text NOT NULL,
 decision text NOT NULL,
 evidence_reference text,
 reason text,
 decided_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(case_id,approval_role,approver_actor),
 CONSTRAINT monetization_approval_role_chk CHECK(approval_role IN ('INSTRUMENT_AUTHENTICATION','COMPLIANCE','LEGAL','TREASURY','CUSTODY','RISK','GOVERNANCE','OTHER')),
 CONSTRAINT monetization_approval_decision_chk CHECK(decision IN ('APPROVED','REJECTED','REVOKED')),
 CONSTRAINT monetization_approval_evidence_chk CHECK(decision<>'APPROVED' OR evidence_reference IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS capitalization.monetization_state_history (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 case_id uuid NOT NULL REFERENCES capitalization.monetization_cases(id) ON DELETE RESTRICT,
 prior_state text,
 new_state text NOT NULL,
 prior_record jsonb NOT NULL,
 new_record jsonb NOT NULL,
 changed_by_actor text,
 changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS monetization_one_active_encumbrance_per_case
 ON capitalization.instrument_encumbrances(case_id)
 WHERE status='ACTIVE';

CREATE OR REPLACE FUNCTION capitalization.validate_monetization_case()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
DECLARE
 required_approvals integer;
 failed_dd integer;
 qualified_platform integer;
 verified_facility integer;
 active_encumbrances integer;
BEGIN
 IF NEW.deployable_cash>NEW.realized_liquidity THEN
  RAISE EXCEPTION 'deployable cash cannot exceed realized liquidity' USING ERRCODE='23514';
 END IF;
 IF NEW.case_state IN ('P2_VERIFIED_CANDIDATE','P3_TRANSACTION_QUALIFIED','P4_AUTHORIZED') THEN
  SELECT count(*) INTO qualified_platform FROM capitalization.monetization_counterparties c
   WHERE c.case_id=NEW.id AND c.role_code IN ('PLATFORM','MONETIZER','FUNDER') AND c.status='QUALIFIED';
  IF qualified_platform=0 THEN RAISE EXCEPTION 'qualified monetization counterparty required' USING ERRCODE='23514'; END IF;
  SELECT count(*) INTO failed_dd FROM capitalization.platform_due_diligence d
   JOIN capitalization.monetization_counterparties c ON c.id=d.counterparty_id
   WHERE c.case_id=NEW.id AND d.diligence_status IN ('FAILED','EXPIRED');
  IF failed_dd>0 THEN RAISE EXCEPTION 'failed or expired platform diligence blocks promotion' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.case_state IN ('P3_TRANSACTION_QUALIFIED','P4_AUTHORIZED') THEN
  IF NEW.independent_bank_authentication IS NOT TRUE THEN RAISE EXCEPTION 'independent bank authentication required for P3/P4' USING ERRCODE='23514'; END IF;
  SELECT count(*) INTO verified_facility FROM capitalization.monetization_funding_facilities f
   WHERE f.case_id=NEW.id AND f.facility_status IN ('VERIFIED','APPROVED','FUNDED') AND f.verified_amount>0;
  IF verified_facility=0 THEN RAISE EXCEPTION 'verified funding facility required for P3/P4' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.case_state='P4_AUTHORIZED' THEN
  SELECT count(DISTINCT approval_role) INTO required_approvals FROM capitalization.monetization_approvals a
   WHERE a.case_id=NEW.id AND a.decision='APPROVED' AND a.approval_role IN ('INSTRUMENT_AUTHENTICATION','COMPLIANCE','LEGAL','TREASURY','RISK','GOVERNANCE');
  IF required_approvals<6 THEN RAISE EXCEPTION 'P4 requires instrument, compliance, legal, treasury, risk, and governance approvals' USING ERRCODE='23514'; END IF;
  SELECT count(*) INTO active_encumbrances FROM capitalization.instrument_encumbrances e WHERE e.case_id=NEW.id AND e.status='ACTIVE';
  IF active_encumbrances>1 THEN RAISE EXCEPTION 'conflicting active encumbrances are prohibited' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION capitalization.validate_monetization_transition()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
BEGIN
 IF OLD.case_state IS DISTINCT FROM NEW.case_state THEN
  IF OLD.case_state='PX_SUSPENDED_REJECTED' THEN RAISE EXCEPTION 'suspended/rejected case requires a new case or formal remediation workflow' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.case_state='P0_UNSCREENED' AND NEW.case_state IN ('P1_INTAKE_RECEIVED','PX_SUSPENDED_REJECTED')) OR
          (OLD.case_state='P1_INTAKE_RECEIVED' AND NEW.case_state IN ('P2_VERIFIED_CANDIDATE','PX_SUSPENDED_REJECTED')) OR
          (OLD.case_state='P2_VERIFIED_CANDIDATE' AND NEW.case_state IN ('P3_TRANSACTION_QUALIFIED','PX_SUSPENDED_REJECTED')) OR
          (OLD.case_state='P3_TRANSACTION_QUALIFIED' AND NEW.case_state IN ('P4_AUTHORIZED','PX_SUSPENDED_REJECTED')) OR
          (OLD.case_state='P4_AUTHORIZED' AND NEW.case_state='PX_SUSPENDED_REJECTED')) THEN
   RAISE EXCEPTION 'invalid monetization case transition: % -> %',OLD.case_state,NEW.case_state USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION capitalization.capture_monetization_history()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,capitalization AS $$
BEGIN
 IF OLD.case_state IS DISTINCT FROM NEW.case_state OR OLD.independent_bank_authentication IS DISTINCT FROM NEW.independent_bank_authentication OR OLD.realized_liquidity IS DISTINCT FROM NEW.realized_liquidity OR OLD.deployable_cash IS DISTINCT FROM NEW.deployable_cash THEN
  INSERT INTO capitalization.monetization_state_history(case_id,prior_state,new_state,prior_record,new_record,changed_by_actor)
  VALUES(NEW.id,OLD.case_state,NEW.case_state,to_jsonb(OLD),to_jsonb(NEW),NEW.requested_by_actor);
 END IF;
 RETURN NEW;
END; $$;

CREATE TRIGGER capitalization_monetization_updated_at BEFORE UPDATE ON capitalization.monetization_cases FOR EACH ROW EXECUTE FUNCTION capitalization.set_updated_at();
CREATE TRIGGER capitalization_monetization_transition BEFORE UPDATE ON capitalization.monetization_cases FOR EACH ROW EXECUTE FUNCTION capitalization.validate_monetization_transition();
CREATE TRIGGER capitalization_monetization_validation BEFORE INSERT OR UPDATE ON capitalization.monetization_cases FOR EACH ROW EXECUTE FUNCTION capitalization.validate_monetization_case();
CREATE TRIGGER capitalization_monetization_history AFTER UPDATE ON capitalization.monetization_cases FOR EACH ROW EXECUTE FUNCTION capitalization.capture_monetization_history();
CREATE TRIGGER capitalization_monetization_history_append_only BEFORE UPDATE OR DELETE ON capitalization.monetization_state_history FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();
CREATE TRIGGER capitalization_monetization_approvals_append_only BEFORE UPDATE OR DELETE ON capitalization.monetization_approvals FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();
CREATE TRIGGER capitalization_monetization_evidence_append_only BEFORE UPDATE OR DELETE ON capitalization.monetization_evidence FOR EACH ROW EXECUTE FUNCTION capitalization.prevent_mutation();

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['monetization_cases','monetization_counterparties','platform_due_diligence','instrument_encumbrances','monetization_funding_facilities','monetization_economics','monetization_evidence','monetization_approvals','monetization_state_history'] LOOP
  EXECUTE format('ALTER TABLE capitalization.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON capitalization.%I FROM PUBLIC, anon, authenticated',t);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON capitalization.%I TO service_role',t);
 END LOOP;
END $$;
REVOKE UPDATE,DELETE ON capitalization.monetization_approvals FROM service_role;
REVOKE UPDATE,DELETE ON capitalization.monetization_evidence FROM service_role;
REVOKE UPDATE,DELETE ON capitalization.monetization_state_history FROM service_role;

CREATE OR REPLACE VIEW capitalization_api.monetization_cases WITH (security_invoker=true) AS
SELECT case_reference,external_instrument_reference,instrument_type,submitted_amount,face_amount,asset_code,case_state,
 instrument_recognition_status,instrument_evidence_status,independent_bank_authentication,deployable_cash,realized_liquidity,updated_at,
 'Governance and evidence state only. This projection does not prove bank authentication, enforceability, funding, monetization, trading returns, custody, payment, or settlement finality.'::text disclosure
FROM capitalization.monetization_cases;
REVOKE ALL ON capitalization_api.monetization_cases FROM PUBLIC,anon;
GRANT SELECT ON capitalization_api.monetization_cases TO authenticated,service_role;

COMMENT ON TABLE capitalization.monetization_cases IS 'IBG-08 governed monetization case registry. A case does not create or authenticate a bank undertaking or funding commitment.';
COMMENT ON TABLE capitalization.monetization_funding_facilities IS 'Proposed/verified funding evidence registry; projected financing is not realized liquidity.';
COMMENT ON TABLE capitalization.monetization_economics IS 'Separates projected economics from externally evidenced realized proceeds and net deployable capital.';
COMMIT;