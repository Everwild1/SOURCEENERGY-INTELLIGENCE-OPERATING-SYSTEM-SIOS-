create schema if not exists media_access;
revoke all on schema media_access from public, anon, authenticated;

create table if not exists media_access.roles (
 role_code text primary key, role_name text not null, description text, is_active boolean not null default true, created_at timestamptz not null default now());
create table if not exists media_access.permissions (
 permission_code text primary key, permission_name text not null, description text, created_at timestamptz not null default now());
create table if not exists media_access.role_permissions (
 role_code text not null references media_access.roles(role_code) on delete cascade,
 permission_code text not null references media_access.permissions(permission_code) on delete cascade,
 created_at timestamptz not null default now(), primary key(role_code,permission_code));
create table if not exists media_access.user_role_assignments (
 assignment_id uuid primary key default gen_random_uuid(), user_id uuid not null,
 organization_oid text references public.setc_organizations(oid) on update cascade on delete restrict,
 role_code text not null references media_access.roles(role_code) on delete restrict,
 assignment_state text not null default 'ACTIVE' check (assignment_state in ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
 effective_from timestamptz not null default now(), effective_to timestamptz,
 evidence_reference text, granted_by_user_id uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (effective_to is null or effective_to > effective_from));
create index if not exists idx_media_access_user_roles on media_access.user_role_assignments(user_id,organization_oid,role_code,assignment_state);

insert into media_access.permissions(permission_code,permission_name,description) values
('media.read','Read media records','Read governed Media & Communications records'),
('media.draft','Draft content','Create and edit pre-approval content'),
('media.fact_validate','Validate facts','Validate claims against authoritative evidence'),
('media.editorial_review','Editorial review','Perform editorial review'),
('media.domain_review','Domain review','Perform legal, compliance, finance, regulatory, privacy or security review'),
('media.approve','Approve content','Grant institutional communications approval'),
('media.publish','Publish content','Distribute approved content through official channels'),
('media.correct','Correct content','Issue controlled corrections and supersessions'),
('media.withdraw','Withdraw content','Withdraw distributed content'),
('media.channel_admin','Administer channels','Administer official channels and endpoints'),
('media.rights_admin','Administer rights','Validate and administer media rights'),
('media.incident_manage','Manage incidents','Manage communications and reputation incidents'),
('media.analytics_read','Read analytics','Read distribution and performance analytics'),
('media.access_admin','Administer media access','Grant and revoke Media & Communications roles')
on conflict(permission_code) do update set permission_name=excluded.permission_name,description=excluded.description;

insert into media_access.roles(role_code,role_name,description) values
('MEDIA_VIEWER','Media Viewer','Read-only governed media access'),
('MEDIA_CONTRIBUTOR','Media Contributor','Draft and maintain assigned content'),
('MEDIA_FACT_VALIDATOR','Fact Validator','Validate claims and source evidence'),
('MEDIA_EDITOR','Media Editor','Editorial review and controlled drafting'),
('MEDIA_DOMAIN_REVIEWER','Domain Reviewer','Specialist domain review; appointment must evidence domain authority'),
('MEDIA_APPROVER','Institutional Communications Approver','Approve communications within delegated institutional authority'),
('MEDIA_PUBLISHER','Media Publisher','Publish only approved content to authorized channels'),
('MEDIA_RIGHTS_MANAGER','Rights Manager','Administer media asset rights and licensing'),
('MEDIA_INCIDENT_MANAGER','Incident Manager','Manage crisis/reputation communications incidents'),
('MEDIA_ANALYST','Media Analyst','Read media analytics and distribution performance'),
('MEDIA_ADMIN','Media Administrator','Administer Media & Communications access and operations')
on conflict(role_code) do update set role_name=excluded.role_name,description=excluded.description,is_active=true;

insert into media_access.role_permissions(role_code,permission_code) values
('MEDIA_VIEWER','media.read'),
('MEDIA_CONTRIBUTOR','media.read'),('MEDIA_CONTRIBUTOR','media.draft'),
('MEDIA_FACT_VALIDATOR','media.read'),('MEDIA_FACT_VALIDATOR','media.fact_validate'),
('MEDIA_EDITOR','media.read'),('MEDIA_EDITOR','media.draft'),('MEDIA_EDITOR','media.editorial_review'),
('MEDIA_DOMAIN_REVIEWER','media.read'),('MEDIA_DOMAIN_REVIEWER','media.domain_review'),
('MEDIA_APPROVER','media.read'),('MEDIA_APPROVER','media.approve'),
('MEDIA_PUBLISHER','media.read'),('MEDIA_PUBLISHER','media.publish'),('MEDIA_PUBLISHER','media.correct'),('MEDIA_PUBLISHER','media.withdraw'),
('MEDIA_RIGHTS_MANAGER','media.read'),('MEDIA_RIGHTS_MANAGER','media.rights_admin'),
('MEDIA_INCIDENT_MANAGER','media.read'),('MEDIA_INCIDENT_MANAGER','media.incident_manage'),
('MEDIA_ANALYST','media.read'),('MEDIA_ANALYST','media.analytics_read'),
('MEDIA_ADMIN','media.read'),('MEDIA_ADMIN','media.draft'),('MEDIA_ADMIN','media.fact_validate'),('MEDIA_ADMIN','media.editorial_review'),('MEDIA_ADMIN','media.domain_review'),('MEDIA_ADMIN','media.approve'),('MEDIA_ADMIN','media.publish'),('MEDIA_ADMIN','media.correct'),('MEDIA_ADMIN','media.withdraw'),('MEDIA_ADMIN','media.channel_admin'),('MEDIA_ADMIN','media.rights_admin'),('MEDIA_ADMIN','media.incident_manage'),('MEDIA_ADMIN','media.analytics_read'),('MEDIA_ADMIN','media.access_admin')
on conflict do nothing;

create or replace function media_access.has_permission(p_permission text,p_organization_oid text default null)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
   select 1 from media_access.user_role_assignments ura
   join media_access.roles r on r.role_code=ura.role_code and r.is_active
   join media_access.role_permissions rp on rp.role_code=ura.role_code
   where ura.user_id=(select auth.uid()) and ura.assignment_state='ACTIVE'
     and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
     and rp.permission_code=p_permission
     and (ura.organization_oid is null or p_organization_oid is null or ura.organization_oid=p_organization_oid)
 );
$$;
revoke all on function media_access.has_permission(text,text) from public,anon;
grant usage on schema media_access to authenticated;
grant execute on function media_access.has_permission(text,text) to authenticated;

create or replace function public.setc_media_publication_ready(p_content_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.setc_media_content c
  where c.content_id=p_content_id and c.lifecycle_status in ('APPROVED','SCHEDULED','PUBLISHED','CORRECTED')
    and not exists (select 1 from public.setc_media_claims cl where cl.content_id=c.content_id and cl.authoritative_source_required and cl.verification_state<>'VERIFIED')
    and exists (select 1 from public.setc_media_approvals a where a.content_id=c.content_id and a.decision='APPROVED' and (a.approved_version is null or a.approved_version=c.current_version))
 );
$$;
revoke all on function public.setc_media_publication_ready(uuid) from public,anon;
grant execute on function public.setc_media_publication_ready(uuid) to authenticated;

alter table media_access.roles enable row level security;
alter table media_access.permissions enable row level security;
alter table media_access.role_permissions enable row level security;
alter table media_access.user_role_assignments enable row level security;
revoke all on all tables in schema media_access from public,anon,authenticated;

create policy media_content_select on public.setc_media_content for select to authenticated using (media_access.has_permission('media.read',organization_oid));
create policy media_content_insert on public.setc_media_content for insert to authenticated with check (media_access.has_permission('media.draft',organization_oid) and lifecycle_status in ('IDEA','ASSIGNED','DRAFT','FACT_VALIDATION'));
create policy media_content_update_draft on public.setc_media_content for update to authenticated using (media_access.has_permission('media.draft',organization_oid) and lifecycle_status in ('IDEA','ASSIGNED','DRAFT','FACT_VALIDATION','EDITORIAL_REVIEW','DOMAIN_REVIEW','APPROVAL_PENDING')) with check (media_access.has_permission('media.draft',organization_oid) and lifecycle_status in ('IDEA','ASSIGNED','DRAFT','FACT_VALIDATION','EDITORIAL_REVIEW','DOMAIN_REVIEW','APPROVAL_PENDING'));
create policy media_content_update_approver on public.setc_media_content for update to authenticated using (media_access.has_permission('media.approve',organization_oid)) with check (media_access.has_permission('media.approve',organization_oid) and lifecycle_status in ('APPROVAL_PENDING','APPROVED','SCHEDULED'));
create policy media_content_update_publisher on public.setc_media_content for update to authenticated using (media_access.has_permission('media.publish',organization_oid)) with check (media_access.has_permission('media.publish',organization_oid) and lifecycle_status in ('APPROVED','SCHEDULED','PUBLISHED','CORRECTED','SUPERSEDED','ARCHIVED','WITHDRAWN'));

grant select,insert,update on public.setc_media_content to authenticated;
grant select on public.setc_media_content_versions,public.setc_media_fact_links,public.setc_media_reviews,public.setc_media_approvals,public.setc_media_channels,public.setc_media_distribution_events,public.setc_media_corrections,public.setc_media_assignments,public.setc_media_assets,public.setc_media_rights,public.setc_media_claims,public.setc_media_claim_evidence,public.setc_media_incidents,public.setc_media_metrics to authenticated;

comment on schema media_access is 'Private SourceEnergy Media & Communications authorization plane. Role assignment does not create underlying legal, financial, regulatory, governmental or subject-matter authority; delegated authority must be evidenced separately.';
comment on function public.setc_media_publication_ready(uuid) is 'Readiness guard: requires approved lifecycle, approved current version and verified required claims. Does not independently establish truth or authority.';
