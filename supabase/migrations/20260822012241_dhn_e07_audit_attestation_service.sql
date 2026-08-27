create table if not exists dhn_audit.audit_chain (
  chain_entry_id uuid primary key default gen_random_uuid(),
  audit_event_id uuid not null unique references dhn_audit.audit_events(audit_event_id),
  previous_chain_digest text,
  event_digest text not null,
  chain_digest text not null unique,
  canonicalization_version text not null default 'dhn-audit-c14n-v1',
  chain_sequence bigint generated always as identity unique,
  created_at timestamptz not null default now()
);

create table if not exists dhn_attestation.attestation_exports (
  attestation_export_id uuid primary key default gen_random_uuid(),
  attestation_id uuid not null references dhn_attestation.attestations(attestation_id),
  export_class text not null check (export_class in ('internal','external_verifier','ledger_anchor')),
  disclosure_profile text not null default 'privacy_minimized_v1',
  export_digest text not null,
  export_payload jsonb not null,
  status text not null default 'prepared' check (status in ('prepared','released','anchored','revoked')),
  destination_ref text,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique(attestation_id, export_class, export_digest)
);

create index if not exists idx_dhn_audit_chain_sequence on dhn_audit.audit_chain(chain_sequence desc);
create index if not exists idx_dhn_attestation_exports_attestation on dhn_attestation.attestation_exports(attestation_id);
create index if not exists idx_dhn_attestation_exports_status on dhn_attestation.attestation_exports(status);

alter table dhn_audit.audit_chain enable row level security;
alter table dhn_attestation.attestation_exports enable row level security;
revoke all privileges on dhn_audit.audit_chain, dhn_attestation.attestation_exports from public, anon, authenticated;
grant all privileges on dhn_audit.audit_chain, dhn_attestation.attestation_exports to service_role;

create or replace function dhn_audit.append_chain_entry(p_audit_event_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = pg_catalog, dhn_audit
as $$
declare
  v_event dhn_audit.audit_events%rowtype;
  v_previous text;
  v_event_digest text;
  v_chain_digest text;
  v_id uuid;
begin
  select * into v_event from dhn_audit.audit_events where audit_event_id = p_audit_event_id;
  if not found then raise exception 'audit_event_not_found'; end if;
  if exists(select 1 from dhn_audit.audit_chain where audit_event_id = p_audit_event_id) then
    select chain_entry_id into v_id from dhn_audit.audit_chain where audit_event_id = p_audit_event_id;
    return v_id;
  end if;
  select chain_digest into v_previous from dhn_audit.audit_chain order by chain_sequence desc limit 1;
  v_event_digest := encode(extensions.digest(convert_to(concat_ws('|',v_event.audit_event_id::text,v_event.actor_id,v_event.event_type,coalesce(v_event.principal_ref,''),coalesce(v_event.resource_type,''),coalesce(v_event.resource_ref,''),coalesce(v_event.outcome,''),coalesce(v_event.correlation_id,''),coalesce(v_event.policy_version,''),v_event.occurred_at::text,coalesce(v_event.integrity_metadata::text,'{}')),'UTF8'),'sha256'),'hex');
  v_chain_digest := encode(extensions.digest(convert_to(coalesce(v_previous,'GENESIS') || '|' || v_event_digest,'UTF8'),'sha256'),'hex');
  insert into dhn_audit.audit_chain(audit_event_id,previous_chain_digest,event_digest,chain_digest) values(p_audit_event_id,v_previous,v_event_digest,v_chain_digest) returning chain_entry_id into v_id;
  return v_id;
end;
$$;

revoke all on function dhn_audit.append_chain_entry(uuid) from public, anon, authenticated;
grant execute on function dhn_audit.append_chain_entry(uuid) to service_role;
