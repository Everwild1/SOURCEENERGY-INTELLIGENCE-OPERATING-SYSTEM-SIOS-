create or replace function public.setc_media_review_queue()
returns table(review_id uuid, content_id uuid, organization_oid text, title text, review_type text, decision text, reviewer_user_id uuid, notes text, created_at timestamptz)
language sql security invoker set search_path=public,pg_temp as $$
  select r.review_id,r.content_id,c.organization_oid,c.title,r.review_type,r.decision,r.reviewer_user_id,r.notes,r.created_at
  from public.setc_media_reviews r
  join public.setc_media_content c on c.content_id=r.content_id
  where r.decision='PENDING'
    and (
      (r.review_type='FACT' and media_access.has_permission('media.fact_validate',c.organization_oid)) or
      (r.review_type='EDITORIAL' and media_access.has_permission('media.editorial_review',c.organization_oid)) or
      (r.review_type not in ('FACT','EDITORIAL') and media_access.has_permission('media.domain_review',c.organization_oid))
    )
  order by r.created_at asc
$$;
revoke all on function public.setc_media_review_queue() from public,anon;
grant execute on function public.setc_media_review_queue() to authenticated;
