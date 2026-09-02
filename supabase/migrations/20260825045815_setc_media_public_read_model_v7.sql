create or replace view public.setc_media_public_content with (security_invoker=true) as
select
 c.content_id,
 c.organization_oid,
 c.title,
 c.slug,
 c.content_type,
 c.representation_class,
 c.summary,
 c.body_markdown,
 c.language_code,
 c.jurisdiction,
 c.current_version,
 c.published_at,
 c.updated_at,
 exists(select 1 from public.setc_media_corrections x where x.content_id=c.content_id and x.correction_status in ('APPROVED','PUBLISHED','CLOSED')) as has_correction
from public.setc_media_content c
where c.lifecycle_status='PUBLISHED'
  and c.published_at is not null
  and public.setc_media_publication_ready(c.content_id);
comment on view public.setc_media_public_content is 'Public Media read model. Exposes only published, publication-ready content; underlying source systems remain authoritative for institutional facts.';
revoke all on public.setc_media_public_content from public,authenticated;
grant select on public.setc_media_public_content to anon;

drop policy if exists media_public_published_read on public.setc_media_content;
create policy media_public_published_read on public.setc_media_content for select to anon
using (lifecycle_status='PUBLISHED' and published_at is not null and public.setc_media_publication_ready(content_id));

drop policy if exists media_public_corrections_read on public.setc_media_corrections;
create policy media_public_corrections_read on public.setc_media_corrections for select to anon
using (correction_status in ('PUBLISHED','CLOSED') and exists(
 select 1 from public.setc_media_content c where c.content_id=setc_media_corrections.content_id and c.lifecycle_status='PUBLISHED'
));

grant select on public.setc_media_content to anon;
grant select on public.setc_media_corrections to anon;
