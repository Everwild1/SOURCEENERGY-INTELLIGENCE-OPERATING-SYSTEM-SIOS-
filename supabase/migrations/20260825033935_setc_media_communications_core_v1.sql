create table if not exists public.setc_media_content (
  content_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid) on update cascade on delete restrict,
  title text not null,
  slug text,
  content_type text not null,
  representation_class text not null check (representation_class in ('EDITORIAL','CORPORATE','RESEARCH','MARKETING','PUBLIC_AFFAIRS','FINANCIAL','REGULATORY','CRISIS')),
  lifecycle_status text not null default 'IDEA' check (lifecycle_status in ('IDEA','ASSIGNED','DRAFT','FACT_VALIDATION','EDITORIAL_REVIEW','DOMAIN_REVIEW','APPROVAL_PENDING','APPROVED','SCHEDULED','PUBLISHED','CORRECTED','SUPERSEDED','ARCHIVED','WITHDRAWN')),
  summary text,
  body_markdown text,
  language_code text not null default 'en',
  jurisdiction text,
  classification text not null default 'INTERNAL',
  owner_user_id uuid,
  published_at timestamptz,
  current_version integer not null default 1 check (current_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organization_oid, slug)
);
comment on table public.setc_media_content is 'Canonical SourceEnergy Media & Communications content registry. Publication records do not independently establish the truth, legal effect, financial recognition, regulatory status, partnership status, or institutional authority of underlying claims.';

create table if not exists public.setc_media_content_versions (
  version_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete cascade,
  version_number integer not null check (version_number > 0),
  title text not null,
  summary text,
  body_markdown text,
  change_reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (content_id, version_number)
);

create table if not exists public.setc_media_fact_links (
  fact_link_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete cascade,
  source_system text not null,
  source_object_type text not null,
  source_object_id text not null,
  source_url text,
  assertion_scope text,
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING','VERIFIED','CONFLICT','STALE','REJECTED')),
  verified_by uuid,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (content_id, source_system, source_object_type, source_object_id)
);
comment on table public.setc_media_fact_links is 'Evidence-lineage references to authoritative source systems. A fact link is a reference and does not replace the controlling source system.';

create table if not exists public.setc_media_reviews (
  review_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete cascade,
  review_type text not null check (review_type in ('EDITORIAL','FACT','LEGAL','COMPLIANCE','FINANCE','REGULATORY','PRIVACY','SECURITY','BRAND','EXECUTIVE')),
  reviewer_user_id uuid,
  decision text not null default 'PENDING' check (decision in ('PENDING','APPROVED','CHANGES_REQUIRED','REJECTED','WAIVED')),
  notes text,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_media_approvals (
  approval_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete cascade,
  approval_scope text not null,
  approver_user_id uuid,
  authority_basis text,
  decision text not null default 'PENDING' check (decision in ('PENDING','APPROVED','REJECTED','REVOKED')),
  approved_version integer,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
comment on table public.setc_media_approvals is 'Authorization to communicate approved content only; does not authorize or execute the underlying transaction, financing, partnership, regulatory action, or corporate commitment.';

create table if not exists public.setc_media_channels (
  channel_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid) on update cascade on delete restrict,
  channel_type text not null,
  platform text not null,
  account_or_domain text not null,
  purpose text,
  official boolean not null default false,
  owner_user_id uuid,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','COMPROMISED','RETIRED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, account_or_domain)
);

create table if not exists public.setc_media_distribution_events (
  distribution_event_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete restrict,
  channel_id uuid not null references public.setc_media_channels(channel_id) on delete restrict,
  version_number integer not null,
  event_type text not null check (event_type in ('SCHEDULED','PUBLISHED','UPDATED','CORRECTED','WITHDRAWN','SYNDICATED')),
  external_url text,
  scheduled_at timestamptz,
  occurred_at timestamptz,
  publication_evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_media_corrections (
  correction_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id) on delete restrict,
  original_version integer not null,
  corrected_version integer,
  error_summary text not null,
  corrected_fact text,
  materiality text,
  correction_status text not null default 'OPEN' check (correction_status in ('OPEN','APPROVED','PUBLISHED','CLOSED')),
  approved_by uuid,
  published_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_setc_media_content_org_status on public.setc_media_content(organization_oid, lifecycle_status);
create index if not exists idx_setc_media_content_rep_class on public.setc_media_content(representation_class);
create index if not exists idx_setc_media_fact_links_source on public.setc_media_fact_links(source_system, source_object_type, source_object_id);
create index if not exists idx_setc_media_reviews_content on public.setc_media_reviews(content_id, review_type, decision);
create index if not exists idx_setc_media_approvals_content on public.setc_media_approvals(content_id, decision);
create index if not exists idx_setc_media_distribution_content on public.setc_media_distribution_events(content_id, occurred_at desc);

alter table public.setc_media_content enable row level security;
alter table public.setc_media_content_versions enable row level security;
alter table public.setc_media_fact_links enable row level security;
alter table public.setc_media_reviews enable row level security;
alter table public.setc_media_approvals enable row level security;
alter table public.setc_media_channels enable row level security;
alter table public.setc_media_distribution_events enable row level security;
alter table public.setc_media_corrections enable row level security;

revoke all on public.setc_media_content from anon, authenticated;
revoke all on public.setc_media_content_versions from anon, authenticated;
revoke all on public.setc_media_fact_links from anon, authenticated;
revoke all on public.setc_media_reviews from anon, authenticated;
revoke all on public.setc_media_approvals from anon, authenticated;
revoke all on public.setc_media_channels from anon, authenticated;
revoke all on public.setc_media_distribution_events from anon, authenticated;
revoke all on public.setc_media_corrections from anon, authenticated;
