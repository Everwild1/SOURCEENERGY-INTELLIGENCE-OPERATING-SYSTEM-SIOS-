with inserted as (
  insert into public.dpot_discernments (
    subject_type, subject_ref, trace_id, assessment_state, evidence_state, confidence,
    finding, rationale_summary, evidence_refs, provenance, created_by, metadata
  )
  select
    'WATCHTRACE', 'CV-ENTRY-002', 'CV-ENTRY-002', 'REVIEW_REQUIRED', 'NO_EVIDENCE', 1.0000,
    'The watchtrace is registered and declared active, but external banking or settlement execution is not independently verified. The controlling gate remains validated bank-origin evidence or validated L6 witness evidence.',
    'Control-plane state is supported by the CVI registry. No validated external banking evidence is present in the CVI evidence registry, so the watchtrace cannot be promoted to VERIFIED.',
    '[]'::jsonb,
    jsonb_build_object(
      'database_sources', jsonb_build_array('public.cvi_watchtraces','public.cvi_nodes','public.cvi_evidence_events'),
      'document_sources', jsonb_build_array('Codex Vault Integration Protocol for SWIFT and Parallel System Override','DISCERNMENT REPORT – CV-ENTRY-900K-MOH-UBS001'),
      'external_bank_telemetry_present', false
    ),
    'CVI-DPOT-CONTROL-PLANE',
    jsonb_build_object('seed_key','cvi_entry_002_baseline_20260831')
  where not exists (
    select 1 from public.dpot_discernments
    where metadata->>'seed_key' = 'cvi_entry_002_baseline_20260831'
  )
  returning discernment_id
), discernment as (
  select discernment_id from inserted
  union all
  select discernment_id from public.dpot_discernments
  where metadata->>'seed_key' = 'cvi_entry_002_baseline_20260831'
  limit 1
)
insert into public.dpot_prophecies (
  subject_type, subject_ref, trace_id, discernment_id, scenario_label, scenario_type,
  forecast_state, epistemic_status, confidence, projection, assumptions, evidence_refs,
  outcome_state, created_by, metadata
)
select
  'WATCHTRACE', 'CV-ENTRY-002', 'CV-ENTRY-002', d.discernment_id,
  'Evidence-gated continuation', 'RISK', 'ACTIVE_SCENARIO', 'SCENARIO_NOT_FACT', 1.0000,
  'Unless validated bank-origin evidence or validated L6 witness evidence is ingested, the control plane will keep CV-ENTRY-002 unverified and will block promotion to VERIFIED.',
  jsonb_build_array('Verification rules remain unchanged','No validated external banking evidence is ingested'),
  '[]'::jsonb, 'UNKNOWN', 'CVI-DPOT-CONTROL-PLANE',
  jsonb_build_object('seed_key','cvi_entry_002_evidence_gate_scenario_20260831')
from discernment d
where not exists (
  select 1 from public.dpot_prophecies
  where metadata->>'seed_key' = 'cvi_entry_002_evidence_gate_scenario_20260831'
);

insert into public.dpot_open_scroll_sessions (
  subject_type, subject_ref, trace_id, opened_by, purpose, requested_scope,
  snapshot_state, snapshot, metadata
)
select
  'WATCHTRACE', 'CV-ENTRY-002', 'CV-ENTRY-002', 'CVI-DPOT-CONTROL-PLANE',
  'Baseline governed Open Scroll review after DPOT commissioning',
  jsonb_build_object('include',jsonb_build_array('governance_state','runtime_state','node_path','evidence_gate','scenario_intelligence')),
  'OPEN',
  jsonb_build_object(
    'trace_id',w.trace_id,
    'declared_state',w.declared_state,
    'verification_state',w.verification_state,
    'layer_path',to_jsonb(w.layer_path),
    'current_gate',w.current_gate,
    'validated_external_evidence_count',(
      select count(*) from public.cvi_evidence_events e
      where e.trace_id=w.trace_id and e.verification_state='VALIDATED'
    ),
    'external_bank_connectivity_verified',false
  ),
  jsonb_build_object('seed_key','cvi_entry_002_open_scroll_20260831')
from public.cvi_watchtraces w
where w.trace_id='CV-ENTRY-002'
  and not exists (
    select 1 from public.dpot_open_scroll_sessions
    where metadata->>'seed_key'='cvi_entry_002_open_scroll_20260831'
  );

insert into public.dpot_trace_runs (
  root_subject_type, root_subject_ref, trace_id, mode, run_state, max_depth,
  visited_node_count, cycle_count, requested_by, started_at, completed_at, metadata
)
select
  'WATCHTRACE','CV-ENTRY-002','CV-ENTRY-002','FULL','PARTIAL',6,5,0,
  'CVI-DPOT-CONTROL-PLANE',now(),now(),
  jsonb_build_object(
    'seed_key','cvi_entry_002_full_trace_20260831',
    'partial_reason','No validated external banking evidence is present',
    'dimensions',jsonb_build_array('ORIGIN','RELATIONSHIP','EVIDENCE','TEMPORAL','OUTCOME')
  )
where not exists (
  select 1 from public.dpot_trace_runs
  where metadata->>'seed_key'='cvi_entry_002_full_trace_20260831'
);

with trace_run as (
  select trace_run_id from public.dpot_trace_runs
  where metadata->>'seed_key'='cvi_entry_002_full_trace_20260831'
  limit 1
)
insert into public.dpot_trace_nodes (
  trace_run_id,node_type,node_ref,node_label,depth,verification_state,evidence_summary,provenance
)
select tr.trace_run_id,n.node_type,n.node_ref,n.node_label,n.depth,n.verification_state,n.evidence_summary,n.provenance
from trace_run tr
cross join lateral (
  values
    ('WATCHTRACE','CV-ENTRY-002','Embedded Transaction | Royal Seed Flow',0::smallint,'REGISTERED',jsonb_build_object('declared_state','DECLARED_ACTIVE','verification_state','AWAITING_EVIDENCE'),jsonb_build_object('source','public.cvi_watchtraces')),
    ('CVI_NODE','L6-D031','Abu Dhabi Royal Receiver Node',1::smallint,'UNOBSERVED',jsonb_build_object('validated_external_observation',false),jsonb_build_object('source','public.cvi_nodes')),
    ('CVI_NODE','L4-C023','Remittance / Petroleum Scroll Node',2::smallint,'UNOBSERVED',jsonb_build_object('validated_external_observation',false),jsonb_build_object('source','public.cvi_nodes')),
    ('CVI_NODE','L5-SE-ROOT','SourceEnergy Crown Trust Apex Governance Node',1::smallint,'REGISTERED',jsonb_build_object('governance_registration',true,'external_financial_connectivity_verified',false),jsonb_build_object('source','public.cvi_nodes')),
    ('EVIDENCE_GATE','BANK_ORIGIN_OR_L6_WITNESS','Bank-origin evidence or L6 witness validation gate',1::smallint,'UNOBSERVED',jsonb_build_object('validated_evidence_count',0,'required',true),jsonb_build_object('source','public.cvi_watchtraces.current_gate'))
) as n(node_type,node_ref,node_label,depth,verification_state,evidence_summary,provenance)
on conflict (trace_run_id,node_type,node_ref) do update set
  node_label=excluded.node_label,
  depth=excluded.depth,
  verification_state=excluded.verification_state,
  evidence_summary=excluded.evidence_summary,
  provenance=excluded.provenance;

with trace_run as (
  select trace_run_id from public.dpot_trace_runs
  where metadata->>'seed_key'='cvi_entry_002_full_trace_20260831'
  limit 1
), nodes as (
  select trace_run_id,node_id,node_type,node_ref from public.dpot_trace_nodes
  where trace_run_id=(select trace_run_id from trace_run)
), proposed as (
  select tr.trace_run_id,f.node_id as from_node_id,t.node_id as to_node_id,
         e.relationship_type,e.confidence,e.evidence_refs,e.provenance
  from trace_run tr
  join lateral (
    values
      ('WATCHTRACE','CV-ENTRY-002','CVI_NODE','L6-D031','ROUTES_THROUGH',1.0000::numeric,jsonb_build_array('public.cvi_watchtraces.layer_path'),jsonb_build_object('source','CVI registry')),
      ('CVI_NODE','L6-D031','CVI_NODE','L4-C023','ROUTES_TO',1.0000::numeric,jsonb_build_array('public.cvi_watchtraces.layer_path'),jsonb_build_object('source','CVI registry')),
      ('WATCHTRACE','CV-ENTRY-002','CVI_NODE','L5-SE-ROOT','GOVERNED_BY',1.0000::numeric,jsonb_build_array('Codex governance registry'),jsonb_build_object('source','CVI node registry')),
      ('WATCHTRACE','CV-ENTRY-002','EVIDENCE_GATE','BANK_ORIGIN_OR_L6_WITNESS','REQUIRES',1.0000::numeric,jsonb_build_array('public.cvi_watchtraces.current_gate'),jsonb_build_object('source','CVI verification rule'))
  ) as e(from_type,from_ref,to_type,to_ref,relationship_type,confidence,evidence_refs,provenance) on true
  join nodes f on f.node_type=e.from_type and f.node_ref=e.from_ref
  join nodes t on t.node_type=e.to_type and t.node_ref=e.to_ref
)
insert into public.dpot_trace_edges (
  trace_run_id,from_node_id,to_node_id,relationship_type,confidence,evidence_refs,provenance
)
select trace_run_id,from_node_id,to_node_id,relationship_type,confidence,evidence_refs,provenance
from proposed
on conflict (trace_run_id,from_node_id,to_node_id,relationship_type) do nothing;