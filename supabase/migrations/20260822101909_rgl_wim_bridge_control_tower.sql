insert into wim.organizations(setc_organization_id,legal_name,display_name,organization_type,jurisdiction_code,website_url,verification_status,economic_status,provenance)
values ('SETC-OID-'||md5(lower('Robert Global Logistics LLC')),'Robert Global Logistics LLC','Robert Global Logistics','logistics_provider','US-VA','https://www.robertlogix.com','verified','active',jsonb_build_object('source','RGL canonical SourceEnergy records','integration','RGL-WIM'))
on conflict (setc_organization_id) do update set display_name=excluded.display_name,website_url=excluded.website_url,updated_at=now();

create table if not exists rgl.wim_transaction_links (
 id uuid primary key default gen_random_uuid(),
 shipment_id uuid not null references rgl.shipments(id) on delete cascade,
 wim_transaction_id uuid not null references wim.transactions(id) on delete cascade,
 link_role text not null default 'fulfillment',
 status text not null default 'active',
 created_at timestamptz not null default now(),
 unique(shipment_id,wim_transaction_id,link_role)
);

create table if not exists rgl.wim_corridor_links (
 id uuid primary key default gen_random_uuid(),
 rgl_corridor_id uuid not null references rgl.corridors(id) on delete cascade,
 wim_trade_corridor_id uuid not null references wim.trade_corridors(id) on delete cascade,
 status text not null default 'active',
 created_at timestamptz not null default now(),
 unique(rgl_corridor_id,wim_trade_corridor_id)
);

create or replace view rgl.control_tower_shipments with (security_invoker=true) as
select s.id shipment_id,s.shipment_reference,s.mode,s.status,c.code corridor_code,c.name corridor_name,
       s.planned_departure_at,s.planned_arrival_at,s.actual_departure_at,s.actual_arrival_at,
       o.external_order_id,o.wim_transaction_id,p.name project_name,
       (select max(te.event_at) from rgl.tracking_events te where te.shipment_id=s.id) last_tracking_at,
       (select count(*) from rgl.incidents i where i.shipment_id=s.id and i.status='open') open_incidents,
       (select count(*) from rgl.delivery_evidence de where de.shipment_id=s.id) delivery_evidence_count
from rgl.shipments s
left join rgl.corridors c on c.id=s.corridor_id
left join rgl.orders o on o.id=s.order_id
left join rgl.projects p on p.id=o.project_id;

create or replace view rgl.control_tower_kpis with (security_invoker=true) as
select count(*) total_shipments,
 count(*) filter(where status in ('planned','dispatched','in_transit')) active_shipments,
 count(*) filter(where status='delivered') delivered_shipments,
 count(*) filter(where planned_arrival_at < now() and actual_arrival_at is null) potentially_late_shipments,
 (select count(*) from rgl.incidents where status='open') open_incidents,
 (select coalesce(sum(amount),0) from rgl.invoices where status in ('issued','due','overdue')) open_receivables
from rgl.shipments;

revoke all on schema rgl from anon, authenticated;
revoke all on all tables in schema rgl from anon, authenticated;
revoke all on all sequences in schema rgl from anon, authenticated;

do $$ declare t record; begin
 for t in select tablename from pg_tables where schemaname='rgl' loop
  execute format('alter table rgl.%I enable row level security',t.tablename);
 end loop;
end $$;
