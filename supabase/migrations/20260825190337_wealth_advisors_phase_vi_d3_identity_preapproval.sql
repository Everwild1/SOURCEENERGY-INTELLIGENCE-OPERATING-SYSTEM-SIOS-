create table if not exists wealth_security.identity_preapprovals (
  id uuid primary key default gen_random_uuid(),
  email_normalized text not null,
  role text not null check (role in ('client','advisor','senior_advisor','vp_wealth_advisors','compliance','executive','auditor')),
  active boolean not null default true,
  approved_by uuid references auth.users(id) on delete set null,
  approval_reason text,
  approved_at timestamptz not null default now(),
  expires_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint identity_preapprovals_email_lower check (email_normalized = lower(trim(email_normalized))),
  constraint identity_preapprovals_email_shape check (position('@' in email_normalized) > 1)
);

create unique index if not exists uq_wa_identity_preapproval_active_email_role
on wealth_security.identity_preapprovals(email_normalized, role)
where active = true;

revoke all on wealth_security.identity_preapprovals from public, anon, authenticated;
grant select, insert, update on wealth_security.identity_preapprovals to service_role;

create or replace function wealth_security.bind_preapproved_identity(target_user_id uuid)
returns table(bound_role text, bound boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_pre record;
begin
  if target_user_id is null then
    raise exception 'target_user_id is required';
  end if;

  select lower(trim(u.email)) into v_email
  from auth.users u
  where u.id = target_user_id
    and u.email_confirmed_at is not null;

  if v_email is null then
    raise exception 'user missing or email not confirmed';
  end if;

  for v_pre in
    select p.id, p.role
    from wealth_security.identity_preapprovals p
    where p.email_normalized = v_email
      and p.active = true
      and (p.expires_at is null or p.expires_at > now())
      and p.consumed_at is null
    order by p.approved_at asc
  loop
    insert into wealth_advisors.user_roles(user_id, role, active)
    values (target_user_id, v_pre.role, true)
    on conflict (user_id, role) do update set active = true;

    update wealth_security.identity_preapprovals
    set consumed_by = target_user_id,
        consumed_at = now()
    where id = v_pre.id;

    bound_role := v_pre.role;
    bound := true;
    return next;
  end loop;

  if not found then
    bound_role := null;
    bound := false;
    return next;
  end if;
end;
$$;

revoke all on function wealth_security.bind_preapproved_identity(uuid) from public, anon, authenticated;
grant execute on function wealth_security.bind_preapproved_identity(uuid) to service_role;

create or replace view wealth_security.pending_identity_bindings
with (security_invoker = true)
as
select
  p.id,
  p.email_normalized,
  p.role,
  p.active,
  p.approved_at,
  p.expires_at,
  p.consumed_by,
  p.consumed_at,
  u.id as auth_user_id,
  u.email_confirmed_at,
  case
    when not p.active then 'inactive'
    when p.consumed_at is not null then 'consumed'
    when p.expires_at is not null and p.expires_at <= now() then 'expired'
    when u.id is null then 'awaiting_auth_user'
    when u.email_confirmed_at is null then 'awaiting_email_confirmation'
    else 'ready_to_bind'
  end as binding_status
from wealth_security.identity_preapprovals p
left join auth.users u on lower(trim(u.email)) = p.email_normalized;

revoke all on wealth_security.pending_identity_bindings from public, anon, authenticated;
grant select on wealth_security.pending_identity_bindings to service_role;

