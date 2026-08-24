-- SourceEnergy Insurance — INS-E04 premium, billing and settlement
-- Internal records do not independently prove bank/Source Coin finality, carrier receipt,
-- premium acceptance, coverage effectiveness, or legal discharge of a payment obligation.

create table if not exists public.setc_insurance_premium_schedules (
  premium_schedule_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  schedule_type text not null check (schedule_type in ('single','monthly','quarterly','semiannual','annual','custom')),
  total_amount numeric(24,6) not null check (total_amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  installment_count integer not null default 1 check (installment_count > 0),
  effective_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_invoices (
  invoice_id uuid primary key default gen_random_uuid(),
  premium_schedule_id uuid references public.setc_insurance_premium_schedules(premium_schedule_id),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  billed_organization_oid text not null references public.setc_organizations(oid),
  invoice_number text not null unique,
  amount_due numeric(24,6) not null check (amount_due >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  due_at timestamptz,
  invoice_status text not null default 'open' check (invoice_status in ('draft','open','partially_paid','paid','past_due','cancelled','void')),
  external_document_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_payments (
  payment_id uuid primary key default gen_random_uuid(),
  payer_organization_oid text references public.setc_organizations(oid),
  receiving_organization_oid text references public.setc_organizations(oid),
  amount numeric(24,6) not null check (amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  payment_method text,
  internal_status text not null default 'recorded' check (internal_status in ('recorded','pending_external_confirmation','externally_confirmed','failed','reversed','void')),
  external_settlement_system text,
  external_settlement_reference text,
  external_evidence_ref text,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  check (internal_status <> 'externally_confirmed' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_payment_allocations (
  payment_allocation_id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.setc_insurance_payments(payment_id),
  invoice_id uuid not null references public.setc_insurance_invoices(invoice_id),
  allocated_amount numeric(24,6) not null check (allocated_amount > 0),
  created_at timestamptz not null default now(),
  unique(payment_id, invoice_id)
);

create table if not exists public.setc_insurance_refunds (
  refund_id uuid primary key default gen_random_uuid(),
  payment_id uuid references public.setc_insurance_payments(payment_id),
  policy_id uuid references public.setc_insurance_policies(policy_id),
  recipient_organization_oid text references public.setc_organizations(oid),
  amount numeric(24,6) not null check (amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  refund_status text not null default 'recorded' check (refund_status in ('recorded','pending_external_confirmation','externally_confirmed','failed','reversed','void')),
  reason text,
  external_settlement_reference text,
  external_evidence_ref text,
  created_at timestamptz not null default now(),
  check (refund_status <> 'externally_confirmed' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_commissions_fees (
  commission_fee_id uuid primary key default gen_random_uuid(),
  policy_id uuid references public.setc_insurance_policies(policy_id),
  invoice_id uuid references public.setc_insurance_invoices(invoice_id),
  payee_organization_oid text references public.setc_organizations(oid),
  fee_type text not null check (fee_type in ('commission','broker_fee','mga_fee','admin_fee','tax','assessment','other')),
  amount numeric(24,6) not null check (amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'accrued' check (status in ('accrued','payable','paid','reversed','waived','void')),
  evidence_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_settlement_reconciliations (
  reconciliation_id uuid primary key default gen_random_uuid(),
  policy_id uuid references public.setc_insurance_policies(policy_id),
  organization_oid text references public.setc_organizations(oid),
  reconciliation_type text not null check (reconciliation_type in ('premium','payment','refund','commission','carrier_statement','bank_statement','source_coin_reference','other')),
  internal_amount numeric(24,6),
  external_amount numeric(24,6),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  reconciliation_status text not null default 'unreconciled' check (reconciliation_status in ('unreconciled','matched','variance','investigating','resolved','void')),
  external_system text,
  external_reference text,
  external_evidence_ref text,
  reconciled_at timestamptz,
  created_at timestamptz not null default now(),
  check (reconciliation_status <> 'matched' or external_evidence_ref is not null)
);

create index if not exists idx_ins_premium_sched_policy on public.setc_insurance_premium_schedules(policy_id);
create index if not exists idx_ins_invoice_schedule on public.setc_insurance_invoices(premium_schedule_id);
create index if not exists idx_ins_invoice_policy on public.setc_insurance_invoices(policy_id);
create index if not exists idx_ins_invoice_org on public.setc_insurance_invoices(billed_organization_oid);
create index if not exists idx_ins_payment_payer on public.setc_insurance_payments(payer_organization_oid);
create index if not exists idx_ins_payment_receiver on public.setc_insurance_payments(receiving_organization_oid);
create index if not exists idx_ins_alloc_payment on public.setc_insurance_payment_allocations(payment_id);
create index if not exists idx_ins_alloc_invoice on public.setc_insurance_payment_allocations(invoice_id);
create index if not exists idx_ins_refund_payment on public.setc_insurance_refunds(payment_id);
create index if not exists idx_ins_refund_policy on public.setc_insurance_refunds(policy_id);
create index if not exists idx_ins_refund_recipient on public.setc_insurance_refunds(recipient_organization_oid);
create index if not exists idx_ins_fee_policy on public.setc_insurance_commissions_fees(policy_id);
create index if not exists idx_ins_fee_invoice on public.setc_insurance_commissions_fees(invoice_id);
create index if not exists idx_ins_fee_payee on public.setc_insurance_commissions_fees(payee_organization_oid);
create index if not exists idx_ins_recon_policy on public.setc_insurance_settlement_reconciliations(policy_id);
create index if not exists idx_ins_recon_org on public.setc_insurance_settlement_reconciliations(organization_oid);

alter table public.setc_insurance_premium_schedules enable row level security;
alter table public.setc_insurance_invoices enable row level security;
alter table public.setc_insurance_payments enable row level security;
alter table public.setc_insurance_payment_allocations enable row level security;
alter table public.setc_insurance_refunds enable row level security;
alter table public.setc_insurance_commissions_fees enable row level security;
alter table public.setc_insurance_settlement_reconciliations enable row level security;

revoke all privileges on public.setc_insurance_premium_schedules, public.setc_insurance_invoices,
 public.setc_insurance_payments, public.setc_insurance_payment_allocations, public.setc_insurance_refunds,
 public.setc_insurance_commissions_fees, public.setc_insurance_settlement_reconciliations from anon, authenticated;
grant all privileges on public.setc_insurance_premium_schedules, public.setc_insurance_invoices,
 public.setc_insurance_payments, public.setc_insurance_payment_allocations, public.setc_insurance_refunds,
 public.setc_insurance_commissions_fees, public.setc_insurance_settlement_reconciliations to service_role;

comment on table public.setc_insurance_payments is 'Internal insurance payment record. externally_confirmed requires evidence but does not independently prove legal settlement finality.';
comment on table public.setc_insurance_settlement_reconciliations is 'Reconciliation evidence layer. A matched record requires external evidence and does not replace authoritative bank, carrier, or settlement-system records.';