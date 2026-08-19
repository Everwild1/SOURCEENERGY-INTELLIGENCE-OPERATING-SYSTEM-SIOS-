-- SC-E12 / RC1: Source Coin release gate and final database hardening.
-- This migration establishes readiness state only. It does NOT authorize production economics.

-- Close the remaining mutable search_path warning on the append-only trigger function.
create or replace function source_coin.prevent_ledger_mutation()
returns trigger
language plpgsql
set search_path = source_coin, pg_temp
as $$
begin
  raise exception 'SOURCE_COIN_LEDGER_APPEND_ONLY';
end;
$$;

revoke all on function source_coin.prevent_ledger_mutation() from public, anon, authenticated;

-- Singleton release-gate record. Defaults are deliberately NO-GO.
create table if not exists source_coin.release_gate_state (
  singleton boolean primary key default true check (singleton),
  release_ref text not null,
  audit_ready boolean not null default false,
  activation_authorized boolean not null default false,
  production_mint_enabled boolean not null default false,
  production_burn_enabled boolean not null default false,
  treasury_issuance_enabled boolean not null default false,
  production_economy_enabled boolean not null default false,
  authorization_ref text,
  authorization_scope text,
  changed_by text not null,
  change_reason text not null,
  changed_at timestamptz not null default now(),
  check (not activation_authorized or audit_ready),
  check (not production_mint_enabled or activation_authorized),
  check (not production_burn_enabled or activation_authorized),
  check (not treasury_issuance_enabled or activation_authorized),
  check (not production_economy_enabled or activation_authorized),
  check (not activation_authorized or authorization_ref is not null),
  check (not activation_authorized or authorization_scope is not null)
);

alter table source_coin.release_gate_state enable row level security;
revoke all on source_coin.release_gate_state from anon, authenticated;

-- Seed a non-activating RC1 gate record if none exists.
insert into source_coin.release_gate_state(
  singleton,
  release_ref,
  audit_ready,
  activation_authorized,
  production_mint_enabled,
  production_burn_enabled,
  treasury_issuance_enabled,
  production_economy_enabled,
  changed_by,
  change_reason
)
values (
  true,
  'SC-RC1',
  false,
  false,
  false,
  false,
  false,
  false,
  'migration-010',
  'Initial RC1 release gate: NO-GO pending independent audit evidence and explicit governance authorization.'
)
on conflict (singleton) do nothing;

-- Database-level assertion surface for operators and audit evidence.
create or replace view source_coin.release_gate_status as
select
  release_ref,
  audit_ready,
  activation_authorized,
  production_mint_enabled,
  production_burn_enabled,
  treasury_issuance_enabled,
  production_economy_enabled,
  authorization_ref,
  authorization_scope,
  changed_by,
  change_reason,
  changed_at,
  (
    audit_ready
    and activation_authorized
    and authorization_ref is not null
    and authorization_scope is not null
  ) as governance_gate_satisfied
from source_coin.release_gate_state
where singleton = true;

revoke all on source_coin.release_gate_status from anon, authenticated;

comment on table source_coin.release_gate_state is
'SC-E12 governed production release gate. Defaults to NO-GO; audit readiness alone never authorizes activation.';
comment on view source_coin.release_gate_status is
'Auditable Source Coin release posture. Economic flags remain false until separately authorized governance action.';
