create table if not exists intelligence_authority.resource_bindings (
  resource_code text primary key references intelligence_authority.protected_resources(resource_code) on delete restrict,
  binding_mode text not null check (binding_mode in ('GUARDED_WRITER','TRIGGER_CONTEXT_AWARE','DIRECT_TRIGGER')),
  writer_function text,
  trigger_name text,
  binding_status text not null default 'ACTIVE',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function intelligence_authority.require_mutation_context(
  p_resource_code text,
  p_operation text,
  p_target_reference text
) returns boolean language plpgsql set search_path='' as $$
declare v_artifact_text text; v_auth_text text; v_artifact uuid; v_auth uuid;
begin
  v_artifact_text := current_setting('setc.intelligence_artifact_id', true);
  v_auth_text := current_setting('setc.mutation_authorization_id', true);
  if coalesce(v_artifact_text,'') = '' then
    return true;
  end if;
  begin v_artifact := v_artifact_text::uuid; exception when others then raise exception 'Authority boundary denied: invalid setc.intelligence_artifact_id'; end;
  if coalesce(v_auth_text,'') <> '' then begin v_auth := v_auth_text::uuid; exception when others then raise exception 'Authority boundary denied: invalid setc.mutation_authorization_id'; end; end if;
  if not intelligence_authority.enforce_mutation(v_artifact,p_resource_code,p_operation,p_target_reference,v_auth) then
    raise exception 'Authority boundary denied: intelligence artifact lacks governed mutation authorization';
  end if;
  return true;
end $$;

create or replace function intelligence_authority.guard_energy_executive_decision() returns trigger language plpgsql set search_path='' as $$
begin
  perform intelligence_authority.require_mutation_context('ENERGY_EXECUTIVE_DECISIONS',tg_op,coalesce(new.decision_case_id::text,old.decision_case_id::text));
  return case when tg_op='DELETE' then old else new end;
end $$;

drop trigger if exists trg_intelligence_authority_energy_executive_decisions on energy.executive_decision_cases;
create trigger trg_intelligence_authority_energy_executive_decisions
before insert or update or delete on energy.executive_decision_cases
for each row execute function intelligence_authority.guard_energy_executive_decision();

create or replace function intelligence_authority.guard_setc_organization() returns trigger language plpgsql set search_path='' as $$
begin
  perform intelligence_authority.require_mutation_context('SETC_ORGANIZATIONS',tg_op,coalesce(new.oid,old.oid));
  return case when tg_op='DELETE' then old else new end;
end $$;

drop trigger if exists trg_intelligence_authority_setc_organizations on public.setc_organizations;
create trigger trg_intelligence_authority_setc_organizations
before insert or update or delete on public.setc_organizations
for each row execute function intelligence_authority.guard_setc_organization();

insert into intelligence_authority.resource_bindings(resource_code,binding_mode,writer_function,trigger_name,binding_status,notes) values
('ENERGY_EXECUTIVE_DECISIONS','TRIGGER_CONTEXT_AWARE','intelligence_authority.require_mutation_context','trg_intelligence_authority_energy_executive_decisions','ACTIVE','When a transaction declares setc.intelligence_artifact_id, mutation is blocked unless the artifact has completed governed promotion and presents a matching active mutation authorization. Ordinary non-intelligence writes are not reclassified by this trigger.'),
('SETC_ORGANIZATIONS','TRIGGER_CONTEXT_AWARE','intelligence_authority.require_mutation_context','trg_intelligence_authority_setc_organizations','ACTIVE','Protects organization/identity writes originating from declared intelligence context. Existing ordinary writes remain backward-compatible; application services that act on AI/model output must set the intelligence context GUCs.')
on conflict(resource_code) do update set binding_mode=excluded.binding_mode,writer_function=excluded.writer_function,trigger_name=excluded.trigger_name,binding_status=excluded.binding_status,notes=excluded.notes,updated_at=now();

comment on function intelligence_authority.require_mutation_context(text,text,text) is 'Context-aware domain binding. If setc.intelligence_artifact_id is present, the write must pass the SETC authority boundary. Absence of intelligence context preserves backward compatibility and is not proof that an external caller is non-AI.';
