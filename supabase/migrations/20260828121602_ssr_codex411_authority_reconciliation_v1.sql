create table if not exists ecology.ssr_authority_registry (
  authority_code text primary key,
  title text not null,
  registry_designation text not null,
  registry_status text not null,
  source_document_id text not null,
  source_document_title text not null,
  authority_scope text not null,
  evidentiary_rule text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table ecology.ssr_authority_registry enable row level security;
create policy ssr_authority_registry_service_role_all on ecology.ssr_authority_registry for all to service_role using (true) with check (true);
insert into ecology.ssr_authority_registry(authority_code,title,registry_designation,registry_status,source_document_id,source_document_title,authority_scope,evidentiary_rule)
values('SSR-411','SourceEnergy Spatial Registry','Registry Entry 411.IX-01','Active','13PKPLZtLKop4Ui9d47EHwzAJxiMCPjmQ0-Ve5jTHfzA','SSR_Phase_XVII_Cross_Reference_Index','Codex 411 / Book IX Spatial Governance; permanent binding and registry designation authority for the Phase XVII suite.','Distinguish established knowledge, technical architecture, conceptual/governance frameworks, and forward-looking proposals; roadmap state must not be asserted as operational fact.')
on conflict(authority_code) do update set registry_designation=excluded.registry_designation,registry_status=excluded.registry_status,authority_scope=excluded.authority_scope,evidentiary_rule=excluded.evidentiary_rule,updated_at=now();

create table if not exists ecology.ssr_reconciliation_queue (
  id uuid primary key default gen_random_uuid(),
  source_schema text not null,
  source_object text not null,
  source_record_id text not null,
  jurisdiction_code text,
  candidate_designation text,
  candidate_source_reference text,
  source_verification_status text,
  source_reconciliation_status text,
  authority_code text not null references ecology.ssr_authority_registry(authority_code),
  reconciliation_decision text not null check(reconciliation_decision in ('pending_authoritative_match','eligible_for_review','rejected','authoritative_match')),
  decision_reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_schema,source_object,source_record_id)
);
alter table ecology.ssr_reconciliation_queue enable row level security;
create policy ssr_reconciliation_queue_service_role_all on ecology.ssr_reconciliation_queue for all to service_role using (true) with check (true);
insert into ecology.ssr_reconciliation_queue(source_schema,source_object,source_record_id,jurisdiction_code,candidate_designation,candidate_source_reference,source_verification_status,source_reconciliation_status,authority_code,reconciliation_decision,decision_reason)
select 'rgl','spatial_registry_links',id::text,jurisdiction_code,ssr_registry_designation,source_reference,verification_status,reconciliation_status,'SSR-411','pending_authoritative_match','Candidate RGL spatial reference cites Codex 411 / Registry Entry 411.IX-01, but source record remains pending/needs_review and public.ssr_spatial_registry has no authoritative matching record; do not promote.'
from rgl.spatial_registry_links
on conflict(source_schema,source_object,source_record_id) do update set jurisdiction_code=excluded.jurisdiction_code,candidate_designation=excluded.candidate_designation,candidate_source_reference=excluded.candidate_source_reference,source_verification_status=excluded.source_verification_status,source_reconciliation_status=excluded.source_reconciliation_status,reconciliation_decision=excluded.reconciliation_decision,decision_reason=excluded.decision_reason,updated_at=now();

update ecology.execution_evidence_inventory
set evidence_posture='pending_verification',
    authority_boundary='Codex 411 / Registry Entry 411.IX-01 is now verified as an active internal SourceEnergy registry authority from the Phase XVII Cross-Reference Index. Individual RGL spatial links remain candidate records until reconciled to an authoritative SSR spatial asset record; registry authority does not itself verify each infrastructure location.',
    source_snapshot=now(),
    provenance=provenance || jsonb_build_object('authority_code','SSR-411','source_document_id','13PKPLZtLKop4Ui9d47EHwzAJxiMCPjmQ0-Ve5jTHfzA','registry_designation','411.IX-01')
where authority_domain='SPATIAL' and source_schema='rgl' and source_object='spatial_registry_links';

create or replace view ecology.ssr_reconciliation_dashboard as
select q.jurisdiction_code,count(*) as candidate_records,
       count(*) filter(where q.reconciliation_decision='authoritative_match') as authoritative_matches,
       count(*) filter(where q.reconciliation_decision='pending_authoritative_match') as pending_matches,
       a.registry_designation,a.registry_status
from ecology.ssr_reconciliation_queue q join ecology.ssr_authority_registry a on a.authority_code=q.authority_code
group by q.jurisdiction_code,a.registry_designation,a.registry_status;

