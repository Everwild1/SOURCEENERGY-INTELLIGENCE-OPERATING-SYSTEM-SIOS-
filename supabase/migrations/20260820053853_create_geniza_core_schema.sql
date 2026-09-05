create schema if not exists geniza;

revoke all on schema geniza from public;
grant usage on schema geniza to postgres, service_role;

create table geniza.repositories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  country_code text,
  homepage_url text,
  created_at timestamptz not null default now()
);

create table geniza.collections (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid not null references geniza.repositories(id) on delete restrict,
  code text not null unique,
  name text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table geniza.ingestion_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique,
  source_system text not null,
  source_ref text,
  source_sha text,
  license text,
  ingestion_mode text not null default 'metadata-only',
  record_count integer not null default 0 check (record_count >= 0),
  status text not null default 'completed',
  ingested_at timestamptz not null default now(),
  notes text
);

create table geniza.fragments (
  id uuid primary key default gen_random_uuid(),
  geniza_record_id text unique,
  repository_id uuid not null references geniza.repositories(id) on delete restrict,
  collection_id uuid references geniza.collections(id) on delete restrict,
  shelfmark text not null,
  normalized_shelfmark text,
  external_fragment_id text,
  provenance_label text,
  created_at timestamptz not null default now(),
  unique(repository_id, shelfmark)
);

create table geniza.documents (
  id uuid primary key default gen_random_uuid(),
  pgp_id bigint unique,
  document_type text,
  primary_language text,
  date_label text,
  description text,
  source_url text,
  evidence_state text not null default 'SOURCE-METADATA',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table geniza.document_fragments (
  document_id uuid not null references geniza.documents(id) on delete cascade,
  fragment_id uuid not null references geniza.fragments(id) on delete cascade,
  relationship_type text not null default 'described-by',
  created_at timestamptz not null default now(),
  primary key (document_id, fragment_id, relationship_type)
);

create table geniza.rights (
  id uuid primary key default gen_random_uuid(),
  fragment_id uuid references geniza.fragments(id) on delete cascade,
  document_id uuid references geniza.documents(id) on delete cascade,
  metadata_license text,
  image_rights text,
  image_ingested boolean not null default false,
  rights_source text,
  created_at timestamptz not null default now(),
  check (fragment_id is not null or document_id is not null)
);

create table geniza.provenance (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references geniza.ingestion_batches(id) on delete restrict,
  fragment_id uuid references geniza.fragments(id) on delete cascade,
  document_id uuid references geniza.documents(id) on delete cascade,
  source_system text not null,
  source_record_id text,
  source_url text,
  source_sha text,
  assertion_scope text not null default 'metadata',
  verification_state text not null default 'SOURCE-METADATA',
  created_at timestamptz not null default now(),
  check (fragment_id is not null or document_id is not null)
);

create index geniza_fragments_shelfmark_idx on geniza.fragments (shelfmark);
create index geniza_documents_pgp_id_idx on geniza.documents (pgp_id);
create index geniza_provenance_batch_idx on geniza.provenance (batch_id);
create index geniza_provenance_source_record_idx on geniza.provenance (source_system, source_record_id);

alter table geniza.repositories enable row level security;
alter table geniza.collections enable row level security;
alter table geniza.ingestion_batches enable row level security;
alter table geniza.fragments enable row level security;
alter table geniza.documents enable row level security;
alter table geniza.document_fragments enable row level security;
alter table geniza.rights enable row level security;
alter table geniza.provenance enable row level security;

revoke all on all tables in schema geniza from anon, authenticated;
grant all on all tables in schema geniza to service_role;
grant all on all sequences in schema geniza to service_role;

