create table sourceenergy_one.access_contexts (
  id uuid primary key default gen_random_uuid(), subject_id text not null, actor_id uuid default auth.uid(), organization_ref text,
  roles jsonb not null default '[]'::jsonb, permissions jsonb not null default '[]'::jsonb,
  assurance_level text not null default 'standard' check (assurance_level in ('standard','elevated','institutional')),
  expires_at timestamptz, created_at timestamptz not null default now()
);
create table sourceenergy_one.policy_decisions (
  id uuid primary key default gen_random_uuid(), correlation_id uuid not null, subject_id text not null,
  action text not null, resource_type text not null, resource_ref text, decision text not null check (decision in ('allow','deny','require_authorization')),
  policy_refs jsonb not null default '[]'::jsonb, reasons jsonb not null default '[]'::jsonb, evaluated_at timestamptz not null default now()
);
create table sourceenergy_one.domain_adapter_registry (
  adapter_key text primary key, domain text not null, authority text not null, mode text not null default 'read' check (mode in ('read','propose','execute')),
  consequence_ceiling text not null default 'advisory' check (consequence_ceiling in ('advisory','operational','consequential')),
  contract_version text not null default '1.0', enabled boolean not null default false, metadata jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table sourceenergy_one.execution_receipts (
  id uuid primary key default gen_random_uuid(), correlation_id uuid not null, orchestration_plan_id uuid references sourceenergy_one.orchestration_plans(id) on delete restrict,
  adapter_key text references sourceenergy_one.domain_adapter_registry(adapter_key) on delete restrict, external_ref text,
  status text not null check (status in ('proposed','authorized','executed','failed','reversed')),
  receipt jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index on sourceenergy_one.policy_decisions(correlation_id, evaluated_at);
create index on sourceenergy_one.execution_receipts(correlation_id, created_at);

alter table sourceenergy_one.access_contexts enable row level security;
alter table sourceenergy_one.policy_decisions enable row level security;
alter table sourceenergy_one.domain_adapter_registry enable row level security;
alter table sourceenergy_one.execution_receipts enable row level security;
revoke all on sourceenergy_one.access_contexts, sourceenergy_one.policy_decisions, sourceenergy_one.domain_adapter_registry, sourceenergy_one.execution_receipts from public, anon, authenticated;
grant all on sourceenergy_one.access_contexts, sourceenergy_one.policy_decisions, sourceenergy_one.domain_adapter_registry, sourceenergy_one.execution_receipts to service_role;
create policy access_contexts_service_role_all on sourceenergy_one.access_contexts for all to service_role using (true) with check (true);
create policy policy_decisions_service_role_all on sourceenergy_one.policy_decisions for all to service_role using (true) with check (true);
create policy domain_adapter_registry_service_role_all on sourceenergy_one.domain_adapter_registry for all to service_role using (true) with check (true);
create policy execution_receipts_service_role_all on sourceenergy_one.execution_receipts for all to service_role using (true) with check (true);

insert into sourceenergy_one.domain_adapter_registry(adapter_key,domain,authority,mode,consequence_ceiling,enabled,metadata) values
('setc-organizations','organizations','public.setc_organizations','read','advisory',true,'{"purpose":"Resolve governed organization context"}'::jsonb),
('setc-genesis','genesis','public.set_genesis_cubes','propose','consequential',false,'{"purpose":"Promote approved Genesis provenance after explicit gate"}'::jsonb),
('sourcecube','orchestration','SIOS SourceCube registries','propose','consequential',false,'{"purpose":"SourceCube context and orchestration handoff"}'::jsonb)
on conflict (adapter_key) do nothing;

comment on table sourceenergy_one.policy_decisions is 'SE1-08 policy decision record; deny/authorization outcomes must be honored before execution.';
comment on table sourceenergy_one.domain_adapter_registry is 'SE1-09 allowlist for SIOS domain adapters. Disabled by default for consequential write pathways.';
comment on table sourceenergy_one.execution_receipts is 'SE1-10 auditable receipt boundary for proposed/authorized/executed external actions.';
