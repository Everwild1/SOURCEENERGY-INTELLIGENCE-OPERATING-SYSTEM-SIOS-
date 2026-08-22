-- IBG-08 current transaction registration.
-- This seed records evidence/governance state only and deliberately leaves the case at P0.
BEGIN;

INSERT INTO capitalization.monetization_cases(
 case_reference,external_instrument_reference,instrument_type,submitted_amount,face_amount,asset_code,case_state,
 instrument_recognition_status,instrument_evidence_status,independent_bank_authentication,deployable_cash,realized_liquidity,requested_by_actor
) VALUES (
 'MON-SBLC-20260820-0001-14','SBLC-20260820-0001-14','STANDBY_LETTER_OF_CREDIT',170000000,153000000,'USD','P0_UNSCREENED',
 'EVIDENCE_RECEIVED','PARTIAL',false,0,0,'SOURCEENERGY_GOVERNANCE'
)
ON CONFLICT (case_reference) DO NOTHING;

INSERT INTO capitalization.monetization_evidence(case_id,evidence_type,evidence_reference,evidence_status,source_authority,independently_verified)
SELECT c.id,'SOURCE_DOCUMENT','SBLC-20260820-0001-14-verbiage.pdf','RECEIVED','USER_SUPPLIED_DOCUMENT',false
FROM capitalization.monetization_cases c
WHERE c.case_reference='MON-SBLC-20260820-0001-14'
  AND NOT EXISTS (
    SELECT 1 FROM capitalization.monetization_evidence e
    WHERE e.case_id=c.id AND e.evidence_type='SOURCE_DOCUMENT' AND e.evidence_reference='SBLC-20260820-0001-14-verbiage.pdf'
  );

COMMIT;