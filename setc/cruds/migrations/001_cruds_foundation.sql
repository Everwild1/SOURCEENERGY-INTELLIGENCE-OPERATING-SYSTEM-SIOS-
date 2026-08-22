create schema if not exists cruds;

create table cruds.creator_archetypes (
  code text primary key check (code in ('artist','thinker','adventurer','maker','producer','dreamer')),
  name text not null unique,
  description text not null default '',
  sort_order smallint not null unique check (sort_order between 1 and 6),
  active boolean not null default true
);

insert into cruds.creator_archetypes (code,name,sort_order) values
 ('artist','Artist',1),('thinker','Thinker',2),('adventurer','Adventurer',3),
 ('maker','Maker',4),('producer','Producer',5),('dreamer','Dreamer',6)
on conflict (code) do nothing;

create table cruds.creators (
  id uuid primary key default gen_random_uuid(),
  identity_reference text not null unique,
  display_name text not null check (length(trim(display_name)) > 0),
  headline text,
  biography text,
  avatar_url text,
  public_slug text unique,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cruds.creator_archetype_memberships (
  creator_id uuid not null references cruds.creators(id) on delete cascade,
  archetype_code text not null references cruds.creator_archetypes(code),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (creator_id, archetype_code)
);

create unique index cruds_one_primary_archetype_per_creator
  on cruds.creator_archetype_memberships (creator_id) where is_primary;

create table cruds.works (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references cruds.creators(id),
  title text not null check (length(trim(title)) > 0),
  slug text unique,
  summary text,
  work_type text not null default 'other',
  publication_status text not null default 'draft' check (publication_status in ('draft','published','archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cruds.provenance_records (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id),
  evidence_type text not null,
  evidence_reference text not null,
  content_digest text,
  recorded_at timestamptz not null default now(),
  supersedes_id uuid references cruds.provenance_records(id),
  correction_reason text
);

create table cruds.witness_verifications (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id),
  witness_reference text not null unique,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','disputed','revoked')),
  verified_at timestamptz,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table cruds.market_access_requests (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id),
  wim_reference text unique,
  request_status text not null default 'draft',
  request_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cruds.settlement_references (
  id uuid primary key default gen_random_uuid(),
  market_access_request_id uuid not null references cruds.market_access_requests(id),
  rail_type text not null,
  external_reference text not null,
  source_coin_reference text,
  status_projection text not null default 'unknown',
  created_at timestamptz not null default now(),
  unique (rail_type, external_reference)
);

alter table cruds.creator_archetypes enable row level security;
alter table cruds.creators enable row level security;
alter table cruds.creator_archetype_memberships enable row level security;
alter table cruds.works enable row level security;
alter table cruds.provenance_records enable row level security;
alter table cruds.witness_verifications enable row level security;
alter table cruds.market_access_requests enable row level security;
alter table cruds.settlement_references enable row level security;

revoke all on schema cruds from anon, authenticated;
revoke all on all tables in schema cruds from anon, authenticated;

comment on schema cruds is 'CRUDS Universe bounded context. Cross-domain IDs are references; no SETC identity, WIM transaction, Witness Grid cryptographic, or Source Coin ledger authority is duplicated here.';
comment on table cruds.witness_verifications is 'Projection/reference to Witness Grid or approved evidence authority; does not confer legal IP ownership.';
comment on table cruds.settlement_references is 'Settlement projection/reference only; never authoritative ledger or finality state.';
