create table if not exists setc_heartbeat.device_attestations (
  device_attestation_id uuid primary key default gen_random_uuid(),
  sensor_reference text not null,
  device_reference text not null,
  attestation_reference text not null unique,
  firmware_version text not null,
  trust_policy_version text not null,
  decision text not null check (decision in ('trusted','degraded','untrusted','revoked')),
  integrity_digest text not null,
  evaluated_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at > evaluated_at)
);

alter table setc_heartbeat.authentication_assertions
  add column if not exists device_attestation_id uuid references setc_heartbeat.device_attestations(device_attestation_id);

-- Safe because this migration was introduced before production assertions existed.
alter table setc_heartbeat.authentication_assertions
  alter column device_attestation_id set not null;

create index if not exists idx_hb_device_attestations_device_time
  on setc_heartbeat.device_attestations(device_reference, evaluated_at desc);

alter table setc_heartbeat.device_attestations enable row level security;
revoke all on setc_heartbeat.device_attestations from public, anon, authenticated;
grant select, insert, update on setc_heartbeat.device_attestations to service_role;

create policy heartbeat_device_attestations_service_role
on setc_heartbeat.device_attestations
for all to service_role
using (true) with check (true);

create or replace function setc_heartbeat.enforce_trusted_device_attestation()
returns trigger
language plpgsql
security invoker
set search_path = setc_heartbeat, public
as $$
declare
  v_decision text;
  v_expires_at timestamptz;
begin
  select decision, expires_at
    into v_decision, v_expires_at
  from setc_heartbeat.device_attestations
  where device_attestation_id = new.device_attestation_id;

  if v_decision is distinct from 'trusted' then
    raise exception 'device attestation is not trusted';
  end if;

  if v_expires_at is null or v_expires_at <= new.issued_at then
    raise exception 'device attestation is expired for assertion issuance';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_hb_assertion_trusted_device on setc_heartbeat.authentication_assertions;
create trigger trg_hb_assertion_trusted_device
before insert on setc_heartbeat.authentication_assertions
for each row execute function setc_heartbeat.enforce_trusted_device_attestation();

comment on table setc_heartbeat.device_attestations is 'Bounded sensor/device trust evidence for SETC-HB-001. Device trust is not human identity and does not confer substantive authority.';
comment on column setc_heartbeat.authentication_assertions.device_attestation_id is 'Required reference to trusted, unexpired device evidence used at assertion issuance.';