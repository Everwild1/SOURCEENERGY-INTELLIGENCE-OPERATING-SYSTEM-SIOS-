-- SC-E09 Source Coin security hardening.
-- This migration does not enable mint, burn, or production economic operations.

create table if not exists source_coin.security_control_state (
  singleton boolean primary key default true check (singleton),
  emergency_state text not null default 'PAUSED' check (emergency_state in ('ACTIVE','PAUSED')),
  changed_by text not null,
  change_reason text not null,
  changed_at timestamptz not null default now()
);

alter table source_coin.security_control_state enable row level security;
revoke all on source_coin.security_control_state from anon, authenticated;

-- Economic evidence must remain append-only to participant/client roles.
revoke insert, update, delete on source_coin.ledger_events from anon, authenticated;
revoke insert, update, delete on source_coin.transactions from anon, authenticated;

-- Transport/control persistence cannot grant economic authority.
revoke insert, update, delete on source_coin.event_outbox from anon, authenticated;
revoke insert, update, delete on source_coin.event_inbox from anon, authenticated;
revoke insert, update, delete on source_coin.api_idempotency from anon, authenticated;

-- Any SECURITY DEFINER economic function introduced by a migration must use a
-- fixed search_path and explicit EXECUTE grants. This assertion view provides
-- auditable inventory for CI/deployment review.
create or replace view source_coin.security_definer_inventory as
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_userbyid(p.proowner) as owner_name,
  p.proconfig as function_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'source_coin'
  and p.prosecdef = true;

revoke all on source_coin.security_definer_inventory from anon, authenticated;

comment on table source_coin.security_control_state is
'SC-E09 emergency control state. Production activation remains governed by SC-E12.';
comment on view source_coin.security_definer_inventory is
'Audit inventory for Source Coin SECURITY DEFINER functions; review fixed search_path and grants before deployment.';
