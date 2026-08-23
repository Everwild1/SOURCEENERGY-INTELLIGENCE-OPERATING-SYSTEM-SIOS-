-- TST-WP07/WP08 distribution, treasury, payment and reconciliation controls.

CREATE TABLE tst.payment_destinations (
  payment_destination_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_id uuid NOT NULL REFERENCES tst.beneficiaries(beneficiary_id) ON DELETE RESTRICT,
  destination_type text NOT NULL CHECK (destination_type IN ('BANK','CUSTODIAN','OTHER')),
  institution_name text,
  masked_reference text NOT NULL,
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'PENDING_VERIFICATION' CHECK (status IN ('PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','RETIRED','REJECTED')),
  verified_by_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tst.treasury_accounts (
  treasury_account_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stewardship_entity_id uuid NOT NULL REFERENCES tst.stewardship_entities(stewardship_entity_id) ON DELETE RESTRICT,
  institution_name text NOT NULL,
  masked_reference text NOT NULL,
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tst.distributions (
  distribution_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  beneficiary_id uuid NOT NULL REFERENCES tst.beneficiaries(beneficiary_id) ON DELETE RESTRICT,
  allocation_id uuid NOT NULL REFERENCES tst.allocations(allocation_id) ON DELETE RESTRICT,
  requested_amount numeric(24,6) NOT NULL CHECK (requested_amount > 0),
  approved_amount numeric(24,6) CHECK (approved_amount IS NULL OR approved_amount > 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  purpose text NOT NULL CHECK (length(btrim(purpose)) > 0),
  requested_by_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  final_approver_participant_id uuid REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','TREASURY_PENDING','PAYMENT_EXECUTED','SETTLED','RECONCILIATION_PENDING','RECONCILED','CLOSED','HOLD','REJECTED','CANCELLED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  settled_at timestamptz
);
CREATE INDEX tst_distributions_beneficiary_status_idx ON tst.distributions(beneficiary_id,status);
CREATE INDEX tst_distributions_allocation_status_idx ON tst.distributions(allocation_id,status);
CREATE UNIQUE INDEX tst_distributions_correlation_uidx ON tst.distributions(correlation_id);

CREATE TABLE tst.distribution_approvals (
  distribution_approval_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES tst.distributions(distribution_id) ON DELETE RESTRICT,
  approver_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  decision text NOT NULL CHECK (decision IN ('APPROVED','REJECTED','RETURNED','ABSTAINED','RECUSED')),
  authority_reference text,
  decision_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tst.payments (
  payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL UNIQUE REFERENCES tst.distributions(distribution_id) ON DELETE RESTRICT,
  treasury_account_id uuid NOT NULL REFERENCES tst.treasury_accounts(treasury_account_id) ON DELETE RESTRICT,
  payment_destination_id uuid NOT NULL REFERENCES tst.payment_destinations(payment_destination_id) ON DELETE RESTRICT,
  amount numeric(24,6) NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  idempotency_key uuid NOT NULL UNIQUE,
  executed_by_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  external_reference text,
  status text NOT NULL DEFAULT 'EXECUTED' CHECK (status IN ('EXECUTED','SETTLED','FAILED','RETURNED','REVERSED')),
  executed_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz
);

CREATE TABLE tst.reconciliations (
  reconciliation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL UNIQUE REFERENCES tst.payments(payment_id) ON DELETE RESTRICT,
  reconciler_participant_id uuid NOT NULL REFERENCES tst.participants(participant_id) ON DELETE RESTRICT,
  ledger_amount numeric(24,6) NOT NULL CHECK (ledger_amount >= 0),
  settled_amount numeric(24,6) NOT NULL CHECK (settled_amount >= 0),
  difference numeric(24,6) GENERATED ALWAYS AS (settled_amount-ledger_amount) STORED,
  status text NOT NULL DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS','EXCEPTION','COMPLETE','REOPENED')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION tst_private.participant_has_role(p_participant_id uuid,p_role_code text,p_entity_id uuid,p_at timestamptz DEFAULT now())
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
 SELECT EXISTS (
   SELECT 1 FROM tst.participants p
   JOIN tst.role_assignments ra ON ra.participant_id=p.participant_id
   WHERE p.participant_id=p_participant_id
     AND p.stewardship_entity_id=p_entity_id
     AND p.status='ACTIVE'
     AND p.effective_from<=p_at AND (p.effective_to IS NULL OR p.effective_to>p_at)
     AND ra.stewardship_entity_id=p_entity_id
     AND ra.role_code=p_role_code
     AND ra.status='ACTIVE'
     AND ra.effective_from<=p_at AND (ra.effective_to IS NULL OR ra.effective_to>p_at)
 );
$$;

CREATE OR REPLACE FUNCTION tst_private.submit_distribution(p_distribution_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE d tst.distributions%ROWTYPE; a tst.allocations%ROWTYPE; b_ok boolean;
BEGIN
 SELECT * INTO d FROM tst.distributions WHERE distribution_id=p_distribution_id FOR UPDATE;
 IF NOT FOUND OR d.status<>'DRAFT' THEN RAISE EXCEPTION 'distribution not in DRAFT'; END IF;
 SELECT * INTO a FROM tst.allocations WHERE allocation_id=d.allocation_id FOR UPDATE;
 IF NOT FOUND OR a.status<>'ACTIVE' THEN RAISE EXCEPTION 'allocation not active'; END IF;
 IF d.currency<>a.currency THEN RAISE EXCEPTION 'currency mismatch'; END IF;
 IF d.requested_amount > (a.authorized_amount-a.committed_amount) THEN RAISE EXCEPTION 'distribution exceeds uncommitted allocation capacity'; END IF;
 SELECT tst_private.beneficiary_is_distribution_eligible(d.beneficiary_id,current_date) INTO b_ok;
 IF NOT b_ok THEN RAISE EXCEPTION 'beneficiary not distribution eligible'; END IF;
 UPDATE tst.distributions SET status='PENDING_APPROVAL' WHERE distribution_id=p_distribution_id;
END $$;

CREATE OR REPLACE FUNCTION tst_private.approve_distribution(p_distribution_id uuid,p_approver_participant_id uuid,p_approved_amount numeric,p_authority_reference text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE d tst.distributions%ROWTYPE; a tst.allocations%ROWTYPE; entity_id uuid;
BEGIN
 IF p_approved_amount<=0 THEN RAISE EXCEPTION 'approved amount must be positive'; END IF;
 SELECT * INTO d FROM tst.distributions WHERE distribution_id=p_distribution_id FOR UPDATE;
 IF NOT FOUND OR d.status<>'PENDING_APPROVAL' THEN RAISE EXCEPTION 'distribution not pending approval'; END IF;
 IF d.requested_by_participant_id=p_approver_participant_id THEN RAISE EXCEPTION 'initiator cannot be final approver'; END IF;
 SELECT * INTO a FROM tst.allocations WHERE allocation_id=d.allocation_id FOR UPDATE;
 SELECT stewardship_entity_id INTO entity_id FROM tst.funds WHERE fund_id=a.fund_id;
 IF NOT tst_private.participant_has_role(p_approver_participant_id,'TST_TRUSTEE',entity_id) THEN RAISE EXCEPTION 'approver lacks trustee authority'; END IF;
 IF p_approved_amount>d.requested_amount THEN RAISE EXCEPTION 'approved amount exceeds requested amount'; END IF;
 IF p_approved_amount>(a.authorized_amount-a.committed_amount) THEN RAISE EXCEPTION 'approved amount exceeds allocation capacity'; END IF;
 INSERT INTO tst.distribution_approvals(distribution_id,approver_participant_id,decision,authority_reference) VALUES(p_distribution_id,p_approver_participant_id,'APPROVED',p_authority_reference);
 UPDATE tst.allocations SET committed_amount=committed_amount+p_approved_amount WHERE allocation_id=d.allocation_id;
 UPDATE tst.distributions SET approved_amount=p_approved_amount,final_approver_participant_id=p_approver_participant_id,status='APPROVED',approved_at=now() WHERE distribution_id=p_distribution_id;
END $$;

CREATE OR REPLACE FUNCTION tst_private.release_to_treasury(p_distribution_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
BEGIN
 UPDATE tst.distributions SET status='TREASURY_PENDING' WHERE distribution_id=p_distribution_id AND status='APPROVED';
 IF NOT FOUND THEN RAISE EXCEPTION 'distribution not approved'; END IF;
END $$;

CREATE OR REPLACE FUNCTION tst_private.execute_payment(p_distribution_id uuid,p_treasury_account_id uuid,p_payment_destination_id uuid,p_executor_participant_id uuid,p_idempotency_key uuid,p_external_reference text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE d tst.distributions%ROWTYPE; a tst.allocations%ROWTYPE; entity_id uuid; pid uuid; dest tst.payment_destinations%ROWTYPE; acct tst.treasury_accounts%ROWTYPE;
BEGIN
 SELECT * INTO d FROM tst.distributions WHERE distribution_id=p_distribution_id FOR UPDATE;
 IF NOT FOUND OR d.status<>'TREASURY_PENDING' THEN RAISE EXCEPTION 'distribution not treasury ready'; END IF;
 IF d.final_approver_participant_id=p_executor_participant_id THEN RAISE EXCEPTION 'final approver cannot execute payment'; END IF;
 SELECT * INTO a FROM tst.allocations WHERE allocation_id=d.allocation_id;
 SELECT stewardship_entity_id INTO entity_id FROM tst.funds WHERE fund_id=a.fund_id;
 IF NOT tst_private.participant_has_role(p_executor_participant_id,'TST_TREASURY',entity_id) THEN RAISE EXCEPTION 'executor lacks treasury authority'; END IF;
 SELECT * INTO dest FROM tst.payment_destinations WHERE payment_destination_id=p_payment_destination_id AND beneficiary_id=d.beneficiary_id AND status IN ('VERIFIED','ACTIVE');
 IF NOT FOUND THEN RAISE EXCEPTION 'payment destination not verified'; END IF;
 SELECT * INTO acct FROM tst.treasury_accounts WHERE treasury_account_id=p_treasury_account_id AND stewardship_entity_id=entity_id AND status='ACTIVE';
 IF NOT FOUND THEN RAISE EXCEPTION 'treasury account not active'; END IF;
 IF d.currency<>dest.currency OR d.currency<>acct.currency THEN RAISE EXCEPTION 'payment currency mismatch'; END IF;
 INSERT INTO tst.payments(distribution_id,treasury_account_id,payment_destination_id,amount,currency,idempotency_key,executed_by_participant_id,external_reference)
 VALUES(d.distribution_id,p_treasury_account_id,p_payment_destination_id,d.approved_amount,d.currency,p_idempotency_key,p_executor_participant_id,p_external_reference)
 RETURNING payment_id INTO pid;
 UPDATE tst.distributions SET status='PAYMENT_EXECUTED' WHERE distribution_id=p_distribution_id;
 RETURN pid;
END $$;

CREATE OR REPLACE FUNCTION tst_private.confirm_payment_settlement(p_payment_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst AS $$
DECLARE did uuid;
BEGIN
 UPDATE tst.payments SET status='SETTLED',settled_at=now() WHERE payment_id=p_payment_id AND status='EXECUTED' RETURNING distribution_id INTO did;
 IF did IS NULL THEN RAISE EXCEPTION 'payment not executable for settlement'; END IF;
 UPDATE tst.distributions SET status='RECONCILIATION_PENDING',settled_at=now() WHERE distribution_id=did;
END $$;

CREATE OR REPLACE FUNCTION tst_private.complete_reconciliation(p_payment_id uuid,p_reconciler_participant_id uuid,p_ledger_amount numeric,p_settled_amount numeric)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,tst,tst_private AS $$
DECLARE p tst.payments%ROWTYPE; d tst.distributions%ROWTYPE; a tst.allocations%ROWTYPE; entity_id uuid; rid uuid; rec_status text;
BEGIN
 SELECT * INTO p FROM tst.payments WHERE payment_id=p_payment_id FOR UPDATE;
 IF NOT FOUND OR p.status<>'SETTLED' THEN RAISE EXCEPTION 'payment not settled'; END IF;
 IF p.executed_by_participant_id=p_reconciler_participant_id THEN RAISE EXCEPTION 'payment executor cannot be reconciler'; END IF;
 SELECT * INTO d FROM tst.distributions WHERE distribution_id=p.distribution_id FOR UPDATE;
 SELECT * INTO a FROM tst.allocations WHERE allocation_id=d.allocation_id FOR UPDATE;
 SELECT stewardship_entity_id INTO entity_id FROM tst.funds WHERE fund_id=a.fund_id;
 IF NOT tst_private.participant_has_role(p_reconciler_participant_id,'TST_RECONCILER',entity_id) THEN RAISE EXCEPTION 'reconciler lacks authority'; END IF;
 rec_status := CASE WHEN p_ledger_amount=p_settled_amount AND p_settled_amount=p.amount THEN 'COMPLETE' ELSE 'EXCEPTION' END;
 INSERT INTO tst.reconciliations(payment_id,reconciler_participant_id,ledger_amount,settled_amount,status,completed_at)
 VALUES(p_payment_id,p_reconciler_participant_id,p_ledger_amount,p_settled_amount,rec_status,CASE WHEN rec_status='COMPLETE' THEN now() ELSE NULL END)
 RETURNING reconciliation_id INTO rid;
 IF rec_status='COMPLETE' THEN
   UPDATE tst.allocations SET disbursed_amount=disbursed_amount+p.amount WHERE allocation_id=a.allocation_id;
   UPDATE tst.distributions SET status='RECONCILED' WHERE distribution_id=d.distribution_id;
 ELSE
   UPDATE tst.distributions SET status='HOLD' WHERE distribution_id=d.distribution_id;
 END IF;
 RETURN rid;
END $$;

CREATE INDEX tst_payments_status_idx ON tst.payments(status,executed_at);
CREATE INDEX tst_reconciliations_status_idx ON tst.reconciliations(status,created_at);

ALTER TABLE tst.payment_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.treasury_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.distribution_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tst.reconciliations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tst.payment_destinations,tst.treasury_accounts,tst.distributions,tst.distribution_approvals,tst.payments,tst.reconciliations FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON tst.payment_destinations,tst.treasury_accounts,tst.distributions,tst.distribution_approvals,tst.payments,tst.reconciliations TO service_role;
CREATE POLICY payment_destinations_service_role_all ON tst.payment_destinations FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY treasury_accounts_service_role_all ON tst.treasury_accounts FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY distributions_service_role_all ON tst.distributions FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY distribution_approvals_service_role_all ON tst.distribution_approvals FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY payments_service_role_all ON tst.payments FOR ALL TO service_role USING(true) WITH CHECK(true);
CREATE POLICY reconciliations_service_role_all ON tst.reconciliations FOR ALL TO service_role USING(true) WITH CHECK(true);

REVOKE ALL ON FUNCTION tst_private.submit_distribution(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.approve_distribution(uuid,uuid,numeric,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.release_to_treasury(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.execute_payment(uuid,uuid,uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.confirm_payment_settlement(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION tst_private.complete_reconciliation(uuid,uuid,numeric,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION tst_private.submit_distribution(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.approve_distribution(uuid,uuid,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.release_to_treasury(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.execute_payment(uuid,uuid,uuid,uuid,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.confirm_payment_settlement(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION tst_private.complete_reconciliation(uuid,uuid,numeric,numeric) TO service_role;
