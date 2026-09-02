create index if not exists idx_wa_assessments_advisor_user on wealth_advisors.assessments(advisor_user_id);
create index if not exists idx_wa_capital_events_partner on wealth_advisors.capital_events(institution_partner_id);
create index if not exists idx_wa_capital_events_recorded_by on wealth_advisors.capital_events(recorded_by);
create index if not exists idx_wa_capital_events_verified_by on wealth_advisors.capital_events(verified_by);
create index if not exists idx_wa_capital_requests_advisor on wealth_advisors.capital_requests(assigned_advisor_user_id);
create index if not exists idx_wa_capital_requests_enterprise on wealth_advisors.capital_requests(enterprise_id);
create index if not exists idx_wa_client_outcomes_capital_request on wealth_advisors.client_outcomes(capital_request_id);
create index if not exists idx_wa_client_outcomes_referral on wealth_advisors.client_outcomes(referral_id);
create index if not exists idx_wa_client_outcomes_verified_by on wealth_advisors.client_outcomes(verified_by);
create index if not exists idx_wa_clients_created_by on wealth_advisors.clients(created_by);
create index if not exists idx_wa_compliance_events_advisor on wealth_advisors.compliance_events(advisor_user_id);
create index if not exists idx_wa_referrals_advisor on wealth_advisors.referrals(advisor_user_id);
create index if not exists idx_wa_referrals_authority on wealth_advisors.referrals(authority_record_id);
create index if not exists idx_wa_referrals_consent on wealth_advisors.referrals(consent_id);
create index if not exists idx_wa_referrals_partner on wealth_advisors.referrals(partner_id);
create index if not exists idx_wa_roadmap_actions_owner on wealth_advisors.roadmap_actions(owner_user_id);
create index if not exists idx_wa_wealth_roadmaps_advisor on wealth_advisors.wealth_roadmaps(advisor_user_id);

create table if not exists wealth_advisors.documents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  document_category text not null check (document_category in ('identity','income','banking','tax','credit','business','real_estate','capital_readiness','consent','authority','referral','underwriting','closing','outcome','compliance','other')),
  storage_bucket text not null default 'wealth-advisors-private',
  storage_path text not null unique,
  original_filename text,
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  sha256 text,
  evidence_status text not null default 'submitted' check (evidence_status in ('submitted','reviewing','verified','rejected','superseded')),
  uploaded_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  retention_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint documents_client_path_prefix check (split_part(storage_path, '/', 1) = client_id::text)
);

create index if not exists idx_wa_documents_client on wealth_advisors.documents(client_id, created_at desc);
create index if not exists idx_wa_documents_uploaded_by on wealth_advisors.documents(uploaded_by);
create index if not exists idx_wa_documents_verified_by on wealth_advisors.documents(verified_by);
create index if not exists idx_wa_documents_category on wealth_advisors.documents(client_id, document_category);

alter table wealth_advisors.documents enable row level security;

create policy wa_documents_select on wealth_advisors.documents
for select to authenticated
using ((select wealth_security.can_access_client(client_id)));

create policy wa_documents_insert on wealth_advisors.documents
for insert to authenticated
with check ((select wealth_security.can_access_client(client_id)));

create policy wa_documents_staff_update on wealth_advisors.documents
for update to authenticated
using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])))
with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_documents_staff_delete on wealth_advisors.documents
for delete to authenticated
using ((select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive'])));

grant select, insert on wealth_advisors.documents to authenticated;
grant update on wealth_advisors.documents to authenticated;
grant delete on wealth_advisors.documents to authenticated;
grant all on wealth_advisors.documents to service_role;

insert into storage.buckets (id, name, public, file_size_limit)
values ('wealth-advisors-private', 'wealth-advisors-private', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists "wa_private_documents_select" on storage.objects;
create policy "wa_private_documents_select" on storage.objects
for select to authenticated
using (
  bucket_id = 'wealth-advisors-private'
  and exists (
    select 1
    from wealth_advisors.clients c
    where c.id::text = (storage.foldername(name))[1]
      and (select wealth_security.can_access_client(c.id))
  )
);

drop policy if exists "wa_private_documents_insert" on storage.objects;
create policy "wa_private_documents_insert" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'wealth-advisors-private'
  and exists (
    select 1
    from wealth_advisors.clients c
    where c.id::text = (storage.foldername(name))[1]
      and (select wealth_security.can_access_client(c.id))
  )
);

drop policy if exists "wa_private_documents_update" on storage.objects;
create policy "wa_private_documents_update" on storage.objects
for update to authenticated
using (
  bucket_id = 'wealth-advisors-private'
  and exists (
    select 1
    from wealth_advisors.clients c
    where c.id::text = (storage.foldername(name))[1]
      and (select wealth_security.can_access_client(c.id))
  )
)
with check (
  bucket_id = 'wealth-advisors-private'
  and exists (
    select 1
    from wealth_advisors.clients c
    where c.id::text = (storage.foldername(name))[1]
      and (select wealth_security.can_access_client(c.id))
  )
);

drop policy if exists "wa_private_documents_delete" on storage.objects;
create policy "wa_private_documents_delete" on storage.objects
for delete to authenticated
using (
  bucket_id = 'wealth-advisors-private'
  and exists (
    select 1
    from wealth_advisors.clients c
    where c.id::text = (storage.foldername(name))[1]
      and (select wealth_security.can_access_client(c.id))
  )
  and (select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive']))
);

