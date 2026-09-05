create table if not exists public.setc_media_assignments (
 assignment_id uuid primary key default gen_random_uuid(), content_id uuid references public.setc_media_content(content_id) on delete cascade,
 organization_oid text not null references public.setc_organizations(oid) on update cascade on delete restrict,
 assignment_type text not null, desk text, region text, assignee_user_id uuid, brief text, due_at timestamptz,
 status text not null default 'OPEN' check (status in ('OPEN','IN_PROGRESS','BLOCKED','SUBMITTED','CLOSED','CANCELLED')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.setc_media_assets (
 asset_id uuid primary key default gen_random_uuid(), organization_oid text not null references public.setc_organizations(oid) on update cascade on delete restrict,
 content_id uuid references public.setc_media_content(content_id) on delete set null, asset_type text not null,
 storage_provider text, storage_key text, title text, description text, mime_type text, checksum_sha256 text,
 rights_status text not null default 'UNVERIFIED' check (rights_status in ('UNVERIFIED','OWNED','LICENSED','PUBLIC_DOMAIN','RESTRICTED','EXPIRED')),
 classification text not null default 'INTERNAL', created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.setc_media_rights (
 rights_id uuid primary key default gen_random_uuid(), asset_id uuid not null references public.setc_media_assets(asset_id) on delete cascade,
 rights_holder text, license_type text, territory text, permitted_channels text[], starts_at timestamptz, expires_at timestamptz,
 restrictions text, evidence_url text, created_at timestamptz not null default now());

create table if not exists public.setc_media_claims (
 claim_id uuid primary key default gen_random_uuid(), content_id uuid not null references public.setc_media_content(content_id) on delete cascade,
 claim_text text not null, claim_category text not null, materiality text not null default 'STANDARD' check (materiality in ('LOW','STANDARD','HIGH','CRITICAL')),
 verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING','VERIFIED','CONFLICT','REJECTED')),
 authoritative_source_required boolean not null default true, created_at timestamptz not null default now());

create table if not exists public.setc_media_claim_evidence (
 claim_evidence_id uuid primary key default gen_random_uuid(), claim_id uuid not null references public.setc_media_claims(claim_id) on delete cascade,
 source_system text not null, source_object_type text not null, source_object_id text not null, source_url text,
 evidence_role text not null default 'SUPPORTING', verification_state text not null default 'PENDING', verified_by uuid, verified_at timestamptz,
 created_at timestamptz not null default now());

create table if not exists public.setc_media_incidents (
 incident_id uuid primary key default gen_random_uuid(), organization_oid text not null references public.setc_organizations(oid) on update cascade on delete restrict,
 incident_type text not null, severity text not null check (severity in ('LOW','MODERATE','HIGH','CRITICAL')),
 title text not null, description text, status text not null default 'OPEN' check (status in ('OPEN','ASSESSING','RESPONDING','MONITORING','RESOLVED','CLOSED')),
 owner_user_id uuid, opened_at timestamptz not null default now(), resolved_at timestamptz, created_at timestamptz not null default now());

create table if not exists public.setc_media_metrics (
 metric_id uuid primary key default gen_random_uuid(), content_id uuid references public.setc_media_content(content_id) on delete cascade,
 channel_id uuid references public.setc_media_channels(channel_id) on delete cascade, metric_name text not null, metric_value numeric not null,
 measured_at timestamptz not null, source_system text, dimensions jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());

create index if not exists idx_setc_media_assignments_org on public.setc_media_assignments(organization_oid,status);
create index if not exists idx_setc_media_assets_content on public.setc_media_assets(content_id);
create index if not exists idx_setc_media_claims_content on public.setc_media_claims(content_id,verification_state);
create index if not exists idx_setc_media_incidents_org on public.setc_media_incidents(organization_oid,status,severity);
create index if not exists idx_setc_media_metrics_content on public.setc_media_metrics(content_id,measured_at desc);

alter table public.setc_media_assignments enable row level security;
alter table public.setc_media_assets enable row level security;
alter table public.setc_media_rights enable row level security;
alter table public.setc_media_claims enable row level security;
alter table public.setc_media_claim_evidence enable row level security;
alter table public.setc_media_incidents enable row level security;
alter table public.setc_media_metrics enable row level security;

revoke all on public.setc_media_assignments from anon, authenticated;
revoke all on public.setc_media_assets from anon, authenticated;
revoke all on public.setc_media_rights from anon, authenticated;
revoke all on public.setc_media_claims from anon, authenticated;
revoke all on public.setc_media_claim_evidence from anon, authenticated;
revoke all on public.setc_media_incidents from anon, authenticated;
revoke all on public.setc_media_metrics from anon, authenticated;

comment on table public.setc_media_claims is 'Material assertion registry. Verification status governs communication readiness but does not create legal, financial, regulatory, governmental, scientific, or partnership truth.';
comment on table public.setc_media_assets is 'Digital asset registry; rights status must be validated before external distribution.';
