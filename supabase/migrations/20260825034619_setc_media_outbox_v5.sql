create table if not exists public.setc_media_outbox (
 outbox_id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.setc_media_events(event_id) on delete cascade,
 destination_type text not null,
 destination_key text not null,
 idempotency_key text not null,
 delivery_status text not null default 'PENDING' check (delivery_status in ('PENDING','PROCESSING','DELIVERED','FAILED','DEAD_LETTER','CANCELLED')),
 attempt_count integer not null default 0 check (attempt_count >= 0),
 available_at timestamptz not null default now(),
 locked_at timestamptz,
 locked_by text,
 delivered_at timestamptz,
 last_error text,
 response_metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(destination_type,destination_key,idempotency_key)
);
comment on table public.setc_media_outbox is 'Transactional delivery queue for governed Media events. Delivery status is transport evidence only and does not change the truth or authority of the underlying communication.';
create index if not exists idx_setc_media_outbox_pending on public.setc_media_outbox(delivery_status,available_at,created_at);
alter table public.setc_media_outbox enable row level security;
revoke all on public.setc_media_outbox from anon, authenticated;

create or replace function public.setc_media_enqueue_outbox(p_event_id uuid, p_destination_type text, p_destination_key text, p_idempotency_key text)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_id uuid; v_org text;
begin
 select organization_oid into v_org from public.setc_media_events where event_id=p_event_id;
 if v_org is null then raise exception 'MEDIA_EVENT_NOT_FOUND'; end if;
 if not media_access.has_permission(v_org,'media.publish') then raise exception 'MEDIA_OUTBOX_FORBIDDEN'; end if;
 insert into public.setc_media_outbox(event_id,destination_type,destination_key,idempotency_key)
 values(p_event_id,p_destination_type,p_destination_key,p_idempotency_key)
 on conflict(destination_type,destination_key,idempotency_key) do update set updated_at=now()
 returning outbox_id into v_id;
 return v_id;
end $$;
revoke all on function public.setc_media_enqueue_outbox(uuid,text,text,text) from public,anon;
grant execute on function public.setc_media_enqueue_outbox(uuid,text,text,text) to authenticated;

create or replace function public.setc_media_mark_outbox_result(p_outbox_id uuid,p_status text,p_error text default null,p_response jsonb default '{}'::jsonb)
returns void language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if p_status not in ('DELIVERED','FAILED','DEAD_LETTER','CANCELLED') then raise exception 'MEDIA_OUTBOX_STATUS_INVALID'; end if;
 update public.setc_media_outbox set delivery_status=p_status, attempt_count=attempt_count+1,
   delivered_at=case when p_status='DELIVERED' then now() else delivered_at end,
   last_error=p_error,response_metadata=coalesce(p_response,'{}'::jsonb),updated_at=now()
 where outbox_id=p_outbox_id;
 if not found then raise exception 'MEDIA_OUTBOX_NOT_FOUND'; end if;
end $$;
revoke all on function public.setc_media_mark_outbox_result(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace view public.setc_media_publication_queue with (security_invoker=true) as
select o.outbox_id,o.event_id,o.destination_type,o.destination_key,o.delivery_status,o.attempt_count,o.available_at,o.created_at,
       e.organization_oid,e.content_id,e.event_type,e.payload
from public.setc_media_outbox o join public.setc_media_events e on e.event_id=o.event_id;
revoke all on public.setc_media_publication_queue from anon,authenticated;

