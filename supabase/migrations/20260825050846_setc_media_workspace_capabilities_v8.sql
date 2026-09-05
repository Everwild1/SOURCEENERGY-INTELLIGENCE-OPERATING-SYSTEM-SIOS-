create or replace function public.setc_media_my_capabilities()
returns table(organization_oid text, permission_code text)
language sql
security definer
set search_path=public,media_access,pg_temp
as $$
  select distinct ura.organization_oid, rp.permission_code
  from media_access.user_role_assignments ura
  join media_access.role_permissions rp on rp.role_code=ura.role_code
  where ura.user_id=auth.uid()
    and ura.assignment_state='ACTIVE'
    and ura.effective_from<=now()
    and (ura.effective_to is null or ura.effective_to>now())
$$;
revoke all on function public.setc_media_my_capabilities() from public,anon;
grant execute on function public.setc_media_my_capabilities() to authenticated;
comment on function public.setc_media_my_capabilities() is 'Returns only the authenticated caller organization-scoped Media permissions. UI capability discovery only; it does not grant authority and all protected actions remain governed by RLS/command checks.';

create or replace view public.setc_media_public_corrections with (security_invoker=true) as
select x.correction_id,x.content_id,x.original_version,x.corrected_version,x.error_summary,x.corrected_fact,x.materiality,x.published_at,x.created_at
from public.setc_media_corrections x
join public.setc_media_content c on c.content_id=x.content_id
where x.correction_status in ('PUBLISHED','CLOSED')
  and c.lifecycle_status='PUBLISHED'
  and c.published_at is not null
  and public.setc_media_publication_ready(c.content_id);
revoke all on public.setc_media_public_corrections from public,authenticated;
grant select on public.setc_media_public_corrections to anon;
