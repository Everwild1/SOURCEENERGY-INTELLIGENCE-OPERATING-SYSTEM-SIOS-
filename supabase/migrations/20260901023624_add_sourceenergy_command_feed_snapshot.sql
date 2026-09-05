create or replace function public.sourceenergy_command_feed_snapshot()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'schema_version', '1.0',
    'generated_at', clock_timestamp(),
    'source', 'SourceEnergy-command-backend',
    'instruments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', i.id,
          'instrument_code', i.instrument_code,
          'instrument_type', i.instrument_type,
          'message_type', i.message_type,
          'external_reference', i.external_reference,
          'uetr', i.uetr,
          'face_currency', btrim(i.face_currency),
          'face_amount', i.face_amount,
          'tenor_days', i.tenor_days,
          'stated_purpose', i.stated_purpose,
          'applicant_name', i.applicant_name,
          'beneficiary_name', i.beneficiary_name,
          'beneficiary_bank_name', i.beneficiary_bank_name,
          'issuing_bank_name', i.issuing_bank_name,
          'governing_law', i.governing_law,
          'issued_at', i.issued_at,
          'recognition_status', i.recognition_status,
          'evidence_status', i.evidence_status,
          'deployable_cash', i.deployable_cash,
          'realized_liquidity', i.realized_liquidity,
          'source_basis', i.source_basis,
          'created_at', i.created_at,
          'updated_at', i.updated_at
        ) order by i.updated_at desc
      )
      from iotf.instruments i
    ), '[]'::jsonb),
    'transactions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'transaction_request_id', t.transaction_request_id,
          'request_code', t.request_code,
          'instrument_id', t.instrument_id,
          'requested_amount', t.requested_amount,
          'currency', btrim(t.currency),
          'origination_status', t.origination_status,
          'composite_score', t.composite_score,
          'allocation_code', t.allocation_code,
          'approved_amount', t.approved_amount,
          'allocation_status', t.allocation_status,
          'shipment_status', t.shipment_status,
          'shipment_reference', t.shipment_reference
        ) order by t.request_code
      )
      from iotf.executive_transaction_pipeline t
    ), '[]'::jsonb),
    'governance_gates', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'instrument_id', g.instrument_id,
          'allocation_id', g.allocation_id,
          'gate_code', g.gate_code,
          'gate_status', g.gate_status,
          'decision_reference', g.decision_reference,
          'decided_at', g.decided_at,
          'created_at', g.created_at
        ) order by g.created_at, g.gate_code
      )
      from iotf.governance_gates g
    ), '[]'::jsonb),
    'evidence', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'instrument_id', e.instrument_id,
          'evidence_type', e.evidence_type,
          'evidence_reference', e.evidence_reference,
          'evidence_status', e.evidence_status,
          'source_class', e.source_class,
          'received_at', e.received_at,
          'reviewed_at', e.reviewed_at
        ) order by e.received_at desc
      )
      from iotf.instrument_evidence e
    ), '[]'::jsonb),
    'readiness', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'instrument_id', r.instrument_id,
          'operative_status', r.operative_status,
          'swift_transmission_status', r.swift_transmission_status,
          'issuer_acknowledgement_status', r.issuer_acknowledgement_status,
          'transfer_consent_status', r.transfer_consent_status,
          'platform_bank_acceptance_status', r.platform_bank_acceptance_status,
          'custody_settlement_status', r.custody_settlement_status,
          'platform_submission_status', r.platform_submission_status,
          'deployable_cash', r.deployable_cash,
          'realized_liquidity', r.realized_liquidity,
          'updated_at', r.updated_at
        ) order by r.updated_at desc
      )
      from iotf.private_platform_readiness r
    ), '[]'::jsonb),
    'requirements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'instrument_id', r.instrument_id,
          'requirement_code', r.requirement_code,
          'requirement_class', r.requirement_class,
          'requirement_text', r.requirement_text,
          'status', r.status,
          'blocking', r.blocking,
          'evidence_reference', r.evidence_reference,
          'updated_at', r.updated_at
        ) order by r.created_at
      )
      from iotf.private_platform_requirements r
    ), '[]'::jsonb),
    'treasury_positions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'treasury_account_id', s.treasury_account_id,
          'as_of', s.as_of,
          'book_balance', s.book_balance,
          'available_balance', s.available_balance,
          'restricted_balance', s.restricted_balance,
          'committed_balance', s.committed_balance,
          'encumbered_balance', s.encumbered_balance,
          'valuation_asset_code', s.valuation_asset_code,
          'source_authority', s.source_authority,
          'reconciliation_status', s.reconciliation_status
        ) order by s.as_of desc
      )
      from capitalization.treasury_position_snapshots s
    ), '[]'::jsonb),
    'approvals', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'request_reference', a.request_reference,
          'target_type', a.target_type,
          'target_reference', a.target_reference,
          'action_type', a.action_type,
          'required_approvals', a.required_approvals,
          'request_status', a.request_status,
          'policy_reference', a.policy_reference,
          'evidence_reference', a.evidence_reference,
          'requested_at', a.requested_at,
          'expires_at', a.expires_at,
          'decided_at', a.decided_at
        ) order by a.requested_at desc
      )
      from capitalization.approval_requests a
    ), '[]'::jsonb)
  );
$function$;

revoke all on function public.sourceenergy_command_feed_snapshot() from public;
revoke all on function public.sourceenergy_command_feed_snapshot() from anon;
revoke all on function public.sourceenergy_command_feed_snapshot() from authenticated;
grant execute on function public.sourceenergy_command_feed_snapshot() to service_role;

comment on function public.sourceenergy_command_feed_snapshot() is
'Read-only governed projection for the owner-authenticated SourceEnergy Command Center server feed.';
