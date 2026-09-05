-- V30: promote AGB-7D-L-v1 to canonical enforcement for privileged execution.

alter table wealth_ecology.execution_authorizations
  alter column constitutional_gate_version set default 'AGB-7D-L-v1';

alter table wealth_ecology.execution_authorizations
  drop constraint if exists execution_authorizations_constitutional_gate_version_check;
alter table wealth_ecology.execution_authorizations
  add constraint execution_authorizations_constitutional_gate_version_check
  check (constitutional_gate_version is null or constitutional_gate_version='AGB-7D-L-v1');

create or replace function wealth_ecology.validate_execution_authorization()
returns trigger language plpgsql set search_path to '' as $$
declare readiness jsonb;
begin
  if new.authorization_state in ('APPROVED','EXECUTING','EXECUTED') then
    if jsonb_array_length(new.evidence_refs)=0 then
      raise exception 'WE-08 approval/execution requires evidence';
    end if;
    if jsonb_array_length(new.required_approval_refs)=0 then
      raise exception 'WE-08 approval/execution requires approval references';
    end if;
    if new.constitutional_gate_version is distinct from 'AGB-7D-L-v1' then
      raise exception 'V30 privileged authorization requires constitutional_gate_version AGB-7D-L-v1';
    end if;
    if new.constitutional_decision_id is null then
      raise exception 'AGB-7D-L-v1 requires constitutional_decision_id';
    end if;
    readiness:=wealth_ecology.evaluate_decision_readiness_v2(new.constitutional_decision_id);
    if coalesce((readiness->>'authorization_ready')::boolean,false) is not true then
      raise exception 'AGB-7D-L-v1 constitutional readiness not satisfied: %',readiness;
    end if;
  end if;
  if new.authorization_state='EXECUTED' and (new.execution_system is null or new.execution_object_ref is null) then
    raise exception 'WE-08 executed state requires execution system and object reference';
  end if;
  return new;
end;
$$;

comment on column wealth_ecology.execution_authorizations.constitutional_gate_version is
'V30 canonical execution gate. New rows default to AGB-7D-L-v1. NULL is reserved only for pre-V30 provenance and cannot be promoted to APPROVED/EXECUTING/EXECUTED.';
comment on column wealth_ecology.execution_authorizations.constitutional_decision_id is
'Decision whose 7D Genesis, Love invariant, 4P, SECI, scientific firewall and failure state determine constitutional execution readiness.';
