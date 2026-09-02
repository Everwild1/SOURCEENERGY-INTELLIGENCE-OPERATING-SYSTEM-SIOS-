alter table wim.products_services
  add column if not exists verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','restricted')),
  add column if not exists evidence_reference text,
  add column if not exists published_at timestamptz;

create index if not exists idx_wim_products_org on wim.products_services(organization_id);
create index if not exists idx_wim_products_subcluster on wim.products_services(subcluster_id);
create index if not exists idx_wim_products_status on wim.products_services(availability_status, verification_status);

create or replace function wim.enforce_product_service_publishability()
returns trigger
language plpgsql
as $$
declare
  org_status text;
  org_verification text;
begin
  select economic_status, verification_status
    into org_status, org_verification
  from wim.organizations
  where id = new.organization_id;

  if new.availability_status in ('available','limited') then
    if org_status <> 'active' or org_verification <> 'verified' then
      raise exception 'organization must be verified and active to publish supply';
    end if;
    if new.verification_status <> 'verified' then
      raise exception 'offering must be verified before publication';
    end if;
    if new.evidence_reference is null or btrim(new.evidence_reference) = '' then
      raise exception 'verified published offering requires evidence reference';
    end if;
    if new.subcluster_id is null then
      raise exception 'published offering requires verified subcluster binding';
    end if;
    if new.published_at is null then
      new.published_at := now();
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_wim_product_service_publishability on wim.products_services;
create trigger trg_wim_product_service_publishability
before insert or update on wim.products_services
for each row execute function wim.enforce_product_service_publishability();

create or replace function wim.restrict_offerings_for_organization()
returns trigger
language plpgsql
as $$
begin
  if new.economic_status in ('restricted','suspended','inactive') or new.verification_status in ('restricted','suspended') then
    update wim.products_services
      set availability_status = case when availability_status in ('available','limited') then 'unavailable' else availability_status end,
          verification_status = case when new.economic_status='restricted' or new.verification_status='restricted' then 'restricted' else verification_status end,
          updated_at = now()
      where organization_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wim_org_restrict_offerings on wim.organizations;
create trigger trg_wim_org_restrict_offerings
after update of economic_status, verification_status on wim.organizations
for each row when (
  old.economic_status is distinct from new.economic_status
  or old.verification_status is distinct from new.verification_status
)
execute function wim.restrict_offerings_for_organization();

comment on column wim.products_services.verification_status is 'Supplier/offering verification state; verified is required for published supply.';
comment on column wim.products_services.evidence_reference is 'Evidence/provenance reference supporting verification.';
