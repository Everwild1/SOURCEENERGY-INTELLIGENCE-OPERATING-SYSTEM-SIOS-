create table sourceenergy_one.heartbeat_consumption_receipts (
  assertion_digest text primary key,
  assertion_id uuid not null references sourceenergy_one.heartbeat_verification_assertions(id) on delete restrict,
  correlation_id uuid not null,
  purpose text not null,
  consumed_by uuid default auth.uid(),
  consumed_at timestamptz not null default now()
);
create index on sourceenergy_one.heartbeat_consumption_receipts(correlation_id, consumed_at);
alter table sourceenergy_one.heartbeat_consumption_receipts enable row level security;
revoke all on sourceenergy_one.heartbeat_consumption_receipts from public, anon, authenticated;
grant all on sourceenergy_one.heartbeat_consumption_receipts to service_role;
create policy heartbeat_consumption_receipts_service_role_all on sourceenergy_one.heartbeat_consumption_receipts for all to service_role using (true) with check (true);
comment on table sourceenergy_one.heartbeat_consumption_receipts is 'One-time consumption ledger for bounded HeartBeatID assertions. Primary-key digest prevents replay at the authoritative persistence boundary.';
