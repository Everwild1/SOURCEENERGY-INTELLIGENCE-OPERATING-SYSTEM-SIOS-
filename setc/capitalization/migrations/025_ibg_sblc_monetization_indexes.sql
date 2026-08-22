-- IBG-08 performance hardening identified during isolated Supabase advisor validation.
BEGIN;
CREATE INDEX IF NOT EXISTS monetization_counterparties_case_id_idx ON capitalization.monetization_counterparties(case_id);
CREATE INDEX IF NOT EXISTS platform_due_diligence_counterparty_id_idx ON capitalization.platform_due_diligence(counterparty_id);
CREATE INDEX IF NOT EXISTS instrument_encumbrances_counterparty_id_idx ON capitalization.instrument_encumbrances(counterparty_id) WHERE counterparty_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS monetization_funding_facilities_case_id_idx ON capitalization.monetization_funding_facilities(case_id);
CREATE INDEX IF NOT EXISTS monetization_funding_facilities_funder_id_idx ON capitalization.monetization_funding_facilities(funder_counterparty_id);
CREATE INDEX IF NOT EXISTS monetization_economics_case_id_idx ON capitalization.monetization_economics(case_id);
CREATE INDEX IF NOT EXISTS monetization_evidence_case_id_idx ON capitalization.monetization_evidence(case_id);
CREATE INDEX IF NOT EXISTS monetization_approvals_case_id_idx ON capitalization.monetization_approvals(case_id);
CREATE INDEX IF NOT EXISTS monetization_state_history_case_id_idx ON capitalization.monetization_state_history(case_id);
COMMIT;