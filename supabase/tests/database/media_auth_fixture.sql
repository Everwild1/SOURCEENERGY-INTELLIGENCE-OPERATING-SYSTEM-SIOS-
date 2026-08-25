create schema if not exists auth;
create schema if not exists media_access;

create table if not exists auth.users (id uuid primary key, email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid
$$;

create table if not exists media_access.permissions (permission_code text primary key);
create table if not exists media_access.roles (role_code text primary key, role_name text not null);
create table if not exists media_access.role_permissions (
  role_code text not null references media_access.roles(role_code),
  permission_code text not null references media_access.permissions(permission_code),
  primary key(role_code, permission_code)
);
create table if not exists media_access.user_role_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  organization_oid text,
  role_code text not null references media_access.roles(role_code),
  assignment_state text not null default 'ACTIVE',
  effective_from timestamptz not null default now(),
  effective_to timestamptz
);
create table if not exists media_access.test_principals (
  principal_code text primary key,
  user_id uuid not null unique,
  description text
);

insert into media_access.permissions(permission_code) values
 ('media.read'),('media.draft'),('media.fact_validate'),('media.approve'),('media.publish'),('media.correct')
on conflict do nothing;
insert into media_access.roles(role_code,role_name) values
 ('MEDIA_CONTRIBUTOR','Media Contributor'),
 ('MEDIA_FACT_VALIDATOR','Fact Validator'),
 ('MEDIA_APPROVER','Institutional Communications Approver'),
 ('MEDIA_PUBLISHER','Media Publisher')
on conflict do nothing;
insert into media_access.role_permissions(role_code,permission_code) values
 ('MEDIA_CONTRIBUTOR','media.read'),('MEDIA_CONTRIBUTOR','media.draft'),
 ('MEDIA_FACT_VALIDATOR','media.read'),('MEDIA_FACT_VALIDATOR','media.fact_validate'),
 ('MEDIA_APPROVER','media.read'),('MEDIA_APPROVER','media.approve'),
 ('MEDIA_PUBLISHER','media.read'),('MEDIA_PUBLISHER','media.publish')
on conflict do nothing;
insert into media_access.test_principals(principal_code,user_id,description) values
 ('TEST_CONTRIBUTOR','10000000-0000-4000-8000-000000000001','Synthetic contributor'),
 ('TEST_APPROVER','10000000-0000-4000-8000-000000000002','Synthetic approver'),
 ('TEST_PUBLISHER','10000000-0000-4000-8000-000000000003','Synthetic publisher'),
 ('TEST_OUTSIDER','10000000-0000-4000-8000-000000000004','Synthetic outsider')
on conflict do nothing;

create or replace function media_access.assert_test_principal(p_principal_code text) returns uuid language sql stable as $$
  select user_id from media_access.test_principals where principal_code=$1
$$;
create or replace function media_access.test_set_principal(p_principal_code text) returns uuid language plpgsql as $$
declare v uuid;
begin
  v := media_access.assert_test_principal(p_principal_code);
  perform set_config('request.jwt.claim.sub',v::text,true);
  return v;
end $$;
create or replace function media_access.has_permission(p_org text,p_permission text) returns boolean language sql stable as $$
  select exists(
    select 1 from media_access.user_role_assignments ura
    join media_access.role_permissions rp on rp.role_code=ura.role_code
    where ura.user_id=auth.uid()
      and ura.organization_oid is not distinct from p_org
      and ura.assignment_state='ACTIVE'
      and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
      and rp.permission_code=p_permission
  )
$$;

create table if not exists public.setc_media_content (
  content_id uuid primary key default gen_random_uuid(),
  organization_oid text not null,
  title text not null,
  lifecycle_status text not null default 'DRAFT',
  current_version integer not null default 1,
  published_at timestamptz
);
alter table public.setc_media_content enable row level security;
create table if not exists public.setc_media_approvals (
  approval_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id),
  decision text not null,
  approved_version integer
);
create table if not exists public.setc_media_claims (
  claim_id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.setc_media_content(content_id),
  claim_text text not null,
  materiality text not null default 'LOW',
  verification_state text not null default 'PENDING',
  authoritative_source_required boolean not null default true
);
create table if not exists public.setc_media_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null default 'media.content.published',
  organization_oid text,
  content_id uuid references public.setc_media_content(content_id)
);
alter table public.setc_media_events enable row level security;
create table if not exists public.setc_media_outbox (
  outbox_id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.setc_media_events(event_id),
  destination_type text not null,
  destination_key text not null,
  idempotency_key text not null,
  unique(destination_type,destination_key,idempotency_key)
);
alter table public.setc_media_outbox enable row level security;

create or replace function public.setc_media_publication_ready(p_content_id uuid) returns boolean language sql stable as $$
 select exists(
   select 1 from public.setc_media_content c
   where c.content_id=$1 and c.lifecycle_status='APPROVED'
 )
 and exists(
   select 1 from public.setc_media_approvals a
   join public.setc_media_content c on c.content_id=a.content_id
   where a.content_id=$1 and a.decision='APPROVED' and a.approved_version=c.current_version
 )
 and not exists(
   select 1 from public.setc_media_claims cl
   where cl.content_id=$1 and cl.authoritative_source_required and cl.verification_state<>'VERIFIED'
 )
$$;
