-- SC-E02 / SC-E04: atomic ledger execution and canonical SETC organization identity.
-- Apply after 004_source_coin_supabase.sql.

-- Canonical SETC organization identifiers are SETC-OID-<32 lowercase hex chars>.
alter table source_coin.accounts
  alter column organization_id type text using organization_id::text;
alter table source_coin.organization_wallets
  alter column organization_id type text using organization_id::text;

alter table source_coin.accounts
  add constraint source_coin_account_org_oid_chk
  check (organization_id ~ '^SETC-OID-[0-9a-f]{32}$');
alter table source_coin.organization_wallets
  add constraint source_coin_wallet_org_oid_chk
  check (organization_id ~ '^SETC-OID-[0-9a-f]{32}$');

create table if not exists source_coin.wallet_authorizations (
  authorization_id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references source_coin.organization_wallets(wallet_id),
  principal_ref text not null,
  role text not null check (role in ('VIEWER','INITIATOR','APPROVER','SIGNER','TREASURY_OPERATOR','AUDITOR')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (wallet_id, principal_ref, role)
);

alter table source_coin.wallet_authorizations enable row level security;
revoke all on source_coin.wallet_authorizations from anon, authenticated;

-- Balances are derived from settled ledger events, not independently mutable state.
create or replace function source_coin.account_balance(p_account_id uuid)
returns bigint
language sql
stable
security definer
set search_path = source_coin, pg_temp
as $$
  select coalesce(sum(
    case
      when destination_account_id = p_account_id then amount_minor
      when source_account_id = p_account_id then -amount_minor
      else 0
    end
  ), 0)::bigint
  from source_coin.ledger_events;
$$;

revoke all on function source_coin.account_balance(uuid) from public, anon, authenticated;

-- Server-only atomic execution for non-supply movements. MINT/BURN are intentionally rejected here.
create or replace function source_coin.execute_authorized_transaction(p_transaction_id uuid)
returns bigint
language plpgsql
security definer
set search_path = source_coin, pg_temp
as $$
declare
  tx source_coin.transactions%rowtype;
  src source_coin.accounts%rowtype;
  dst source_coin.accounts%rowtype;
  existing_sequence bigint;
  new_sequence bigint;
begin
  select * into tx from source_coin.transactions where transaction_id = p_transaction_id for update;
  if not found then raise exception 'SOURCE_COIN_TRANSACTION_NOT_FOUND'; end if;

  select ledger_sequence into existing_sequence
  from source_coin.ledger_events where transaction_id = p_transaction_id limit 1;
  if existing_sequence is not null then return existing_sequence; end if;

  if tx.status <> 'AUTHORIZED' then raise exception 'SOURCE_COIN_TRANSACTION_NOT_AUTHORIZED'; end if;
  if tx.transaction_type in ('MINT','BURN') then raise exception 'SOURCE_COIN_SUPPLY_OPERATION_DISABLED'; end if;
  if tx.source_account_id is null or tx.destination_account_id is null then raise exception 'SOURCE_COIN_ACCOUNTS_REQUIRED'; end if;
  if tx.source_account_id = tx.destination_account_id then raise exception 'SOURCE_COIN_ACCOUNTS_MUST_DIFFER'; end if;

  select * into src from source_coin.accounts where account_id = tx.source_account_id for update;
  select * into dst from source_coin.accounts where account_id = tx.destination_account_id for update;
  if src.status <> 'ACTIVE' or dst.status <> 'ACTIVE' then raise exception 'SOURCE_COIN_ACCOUNT_INELIGIBLE'; end if;
  if source_coin.account_balance(src.account_id) < tx.amount_minor then raise exception 'SOURCE_COIN_INSUFFICIENT_FUNDS'; end if;

  insert into source_coin.ledger_events(
    transaction_id, event_type, amount_minor, source_account_id, destination_account_id, correlation_id
  ) values (
    tx.transaction_id, 'TRANSACTION_SETTLED', tx.amount_minor, tx.source_account_id, tx.destination_account_id, tx.correlation_id
  ) returning ledger_sequence into new_sequence;

  update source_coin.transactions
  set status = 'SETTLED', executed_at = now()
  where transaction_id = tx.transaction_id;

  return new_sequence;
end;
$$;

revoke all on function source_coin.execute_authorized_transaction(uuid) from public, anon, authenticated;

-- Ledger events are append-only even for privileged database roles using ordinary DML.
create or replace function source_coin.prevent_ledger_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'SOURCE_COIN_LEDGER_APPEND_ONLY';
end;
$$;

create trigger source_coin_ledger_no_update
before update or delete on source_coin.ledger_events
for each row execute function source_coin.prevent_ledger_mutation();

-- Organization lifecycle propagation entry point for trusted SETC server orchestration.
create or replace function source_coin.apply_organization_economic_status(p_organization_id text, p_status text)
returns void
language plpgsql
security definer
set search_path = source_coin, pg_temp
as $$
begin
  if p_organization_id !~ '^SETC-OID-[0-9a-f]{32}$' then raise exception 'SOURCE_COIN_INVALID_ORGANIZATION_ID'; end if;
  if p_status not in ('ACTIVE','SUSPENDED','FROZEN','CLOSED') then raise exception 'SOURCE_COIN_INVALID_STATUS'; end if;
  update source_coin.accounts set status = p_status where organization_id = p_organization_id;
  update source_coin.organization_wallets set status = p_status where organization_id = p_organization_id;
end;
$$;

revoke all on function source_coin.apply_organization_economic_status(text,text) from public, anon, authenticated;
