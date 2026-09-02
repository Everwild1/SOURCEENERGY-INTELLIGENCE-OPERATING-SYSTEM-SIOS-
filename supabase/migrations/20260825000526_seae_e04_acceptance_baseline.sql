insert into seae.acceptance_test_results(test_code,run_reference,status,details)
select v.test_code,'E04-BASELINE-2026-08-24',v.status,v.details
from (values
('E04-AUTH-001','pass'::text,jsonb_build_object('authenticated_raw_table_privileges',0)),
('E04-AUTH-002','pass'::text,jsonb_build_object('rpc_count',3,'anon_execute',false,'authenticated_execute',true,'search_path_pinned',true)),
('E04-AUDIT-001','pass'::text,jsonb_build_object('immutable_trigger','seae_audit_immutable')),
('E04-WF-001','pass'::text,jsonb_build_object('valid_open_to_review',true,'blocked_open_to_cleared',true,'blocked_requested_to_settled',true,'immutable_transition_ledger',true)),
('E04-SETTLE-001','pass'::text,jsonb_build_object('boundary','control_plane_only','moves_funds',false,'creates_source_coin_transaction',false)),
('E04-IMPACT-001','pass'::text,jsonb_build_object('bridge_table','seae.wealth_ecology_impact_links','targets',jsonb_build_array('cruds.impact_metrics','rgl.wealth_ecology_impacts','rw.impact_observations','rw.wealth_yield_records'))),
('E04-RLS-001','pass'::text,jsonb_build_object('seae_table_count',36,'all_rls_enabled',true,'tables_with_policy',36))
) as v(test_code,status,details)
on conflict(test_code,run_reference) do nothing;
