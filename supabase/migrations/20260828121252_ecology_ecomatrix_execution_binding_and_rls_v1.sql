alter table ecology.smart_specialization_domains enable row level security;
alter table ecology.smart_specialization_nodes enable row level security;
alter table ecology.smart_specialization_links enable row level security;

drop policy if exists smart_specialization_domains_service_role_all on ecology.smart_specialization_domains;
create policy smart_specialization_domains_service_role_all on ecology.smart_specialization_domains for all to service_role using (true) with check (true);
drop policy if exists smart_specialization_nodes_service_role_all on ecology.smart_specialization_nodes;
create policy smart_specialization_nodes_service_role_all on ecology.smart_specialization_nodes for all to service_role using (true) with check (true);
drop policy if exists smart_specialization_links_service_role_all on ecology.smart_specialization_links;
create policy smart_specialization_links_service_role_all on ecology.smart_specialization_links for all to service_role using (true) with check (true);

create table if not exists ecology.execution_binding_requirements (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  binding_domain text not null check (binding_domain in ('ENERGY','LOGISTICS','SPATIAL','COMMERCIALIZATION','CAPITAL')),
  target_schema text not null,
  target_object_type text not null,
  requirement_role text not null check (requirement_role in ('required','conditional','optional')),
  readiness_gate text not null,
  authority_boundary text not null,
  verification_status text not null default 'binding_required',
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(node_id,binding_domain,target_schema,target_object_type)
);

create table if not exists ecology.execution_bindings (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  requirement_id uuid references ecology.execution_binding_requirements(id) on delete set null,
  binding_domain text not null check (binding_domain in ('ENERGY','LOGISTICS','SPATIAL','COMMERCIALIZATION','CAPITAL')),
  target_schema text not null,
  target_object_type text not null,
  target_object_id text not null,
  relationship_type text not null,
  verification_status text not null default 'unverified',
  evidence_reference text,
  source_authority text,
  notes text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(node_id,binding_domain,target_schema,target_object_type,target_object_id,relationship_type)
);

create table if not exists ecology.execution_gate_assessments (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references ecology.smart_specialization_nodes(id) on delete cascade,
  gate_code text not null,
  gate_name text not null,
  gate_status text not null check (gate_status in ('not_assessed','blocked','partial','ready_reference','graduated_reference')),
  evidence_reference text,
  authority_reference text,
  assessed_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(node_id,gate_code)
);

alter table ecology.execution_binding_requirements enable row level security;
alter table ecology.execution_bindings enable row level security;
alter table ecology.execution_gate_assessments enable row level security;

create policy execution_binding_requirements_service_role_all on ecology.execution_binding_requirements for all to service_role using (true) with check (true);
create policy execution_bindings_service_role_all on ecology.execution_bindings for all to service_role using (true) with check (true);
create policy execution_gate_assessments_service_role_all on ecology.execution_gate_assessments for all to service_role using (true) with check (true);

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'SPATIAL','public','ssr_spatial_registry','required','spatial_reference_verified','Spatial linkage is reference-only; registry presence does not establish title, jurisdiction, permitting, ownership, or operating authority.',jsonb_build_object('rule','all_nodes_spatial_v1')
from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'COMMERCIALIZATION','wim','commercialization_projects','required','commercialization_case_opened','Commercialization linkage records a governed project reference only and does not constitute an offer, award, sale, financing, or settlement.',jsonb_build_object('rule','all_nodes_commercialization_v1')
from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'CAPITAL','capitalization','release_gates','required','capital_release_gate_defined','Capital binding must remain stage-gated; no record here constitutes committed, funded, drawable, settled, or bank-verified capital.',jsonb_build_object('rule','all_nodes_capital_v1')
from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'LOGISTICS','rgl','projects','conditional','logistics_execution_required','RGL binding is required where physical movement, corridor access, field deployment, delivery, or supply-chain execution is material; linkage does not create carrier authority, contract, shipment, customs clearance, or delivery proof.',jsonb_build_object('rule','physical_execution_logistics_v1')
from ecology.smart_specialization_nodes where node_type='specialization' and (enablement_layer='ENERGY' or domain_code in ('LAND','SEA'))
on conflict do nothing;

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'ENERGY','energy','projects','required','energy_project_reference','Energy specialization requires a governed energy-project reference before execution; project registration does not establish financing, permits, interconnection, ownership, market participation, procurement award, or construction authority.',jsonb_build_object('rule','energy_layer_project_v1')
from ecology.smart_specialization_nodes where node_type='specialization' and enablement_layer='ENERGY'
on conflict do nothing;

insert into ecology.execution_binding_requirements(node_id,binding_domain,target_schema,target_object_type,requirement_role,readiness_gate,authority_boundary,provenance)
select id,'ENERGY','energy','capital_readiness_assessments','conditional','energy_capital_readiness_assessed','Energy capital-readiness assessment is internal decision support only and does not mean financing is committed, lender-approved, funded, or available for draw.',jsonb_build_object('rule','energy_capital_readiness_v1')
from ecology.smart_specialization_nodes where node_type='specialization' and enablement_layer='ENERGY'
on conflict do nothing;

insert into ecology.execution_gate_assessments(node_id,gate_code,gate_name,gate_status,provenance)
select id,'G1-SPATIAL','Spatial Reference Verified','not_assessed',jsonb_build_object('source','EcoMatrix Execution Binding v1') from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;
insert into ecology.execution_gate_assessments(node_id,gate_code,gate_name,gate_status,provenance)
select id,'G2-COMM','Commercialization Case Opened','not_assessed',jsonb_build_object('source','EcoMatrix Execution Binding v1') from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;
insert into ecology.execution_gate_assessments(node_id,gate_code,gate_name,gate_status,provenance)
select id,'G3-CAPITAL','Capital Release Gate Defined','not_assessed',jsonb_build_object('source','EcoMatrix Execution Binding v1') from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;
insert into ecology.execution_gate_assessments(node_id,gate_code,gate_name,gate_status,provenance)
select id,'G4-EXEC','Physical Execution Evidence','not_assessed',jsonb_build_object('source','EcoMatrix Execution Binding v1') from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;
insert into ecology.execution_gate_assessments(node_id,gate_code,gate_name,gate_status,provenance)
select id,'G5-IMPACT','Impact Evidence Recorded','not_assessed',jsonb_build_object('source','EcoMatrix Execution Binding v1') from ecology.smart_specialization_nodes where node_type='specialization'
on conflict do nothing;

create or replace view ecology.execution_binding_readiness as
select n.canonical_code as node_code,n.name as node_name,n.domain_code,n.enablement_layer,n.flow_role,
       count(r.id) as requirement_count,
       count(b.id) filter (where b.verification_status in ('verified_reference','source_verified')) as verified_binding_count,
       count(g.id) filter (where g.gate_status in ('ready_reference','graduated_reference')) as ready_gate_count,
       count(g.id) as gate_count,
       case when count(g.id)>0 and count(g.id) filter (where g.gate_status in ('ready_reference','graduated_reference'))=count(g.id)
            then 'execution_ready_reference' else 'not_execution_ready' end as execution_readiness
from ecology.smart_specialization_nodes n
left join ecology.execution_binding_requirements r on r.node_id=n.id
left join ecology.execution_bindings b on b.requirement_id=r.id
left join ecology.execution_gate_assessments g on g.node_id=n.id
where n.node_type='specialization'
group by n.id,n.canonical_code,n.name,n.domain_code,n.enablement_layer,n.flow_role;

