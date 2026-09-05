insert into wim.markets(name,market_type,country_code,region_code,description,status) values
('United States','geographic','US','NA','RGL Phase I core market','active'),
('Canada','geographic','CA','NA','RGL Phase I core market','active'),
('Mexico','geographic','MX','NA','RGL Phase I core market','active'),
('Jamaica','geographic','JM','CAR','RGL Phase II Caribbean market','active'),
('Dominican Republic','geographic','DO','CAR','RGL Phase II Caribbean market','active'),
('Saint Lucia','geographic','LC','CAR','RGL Phase II Caribbean market','active')
on conflict (name,country_code,region_code) do update set status='active';

with org as (
 select id from wim.organizations where lower(legal_name)=lower('Robert Global Logistics LLC') limit 1
), markets as (
 select id from wim.markets where country_code in ('US','CA','MX','JM','DO','LC')
)
insert into wim.organization_market_memberships(id,organization_id,market_id,market_role,participation_status,verification_status,provenance)
select nextval('wim.organization_market_memberships_id_seq'),org.id,markets.id,'service_provider','active','verified',jsonb_build_object('source','RGL-WIM activation') from org cross join markets
on conflict (organization_id,market_id,market_role) do update set participation_status='active',verification_status='verified',updated_at=now();

insert into wim.trade_corridors(name,origin_market_id,destination_market_id,status,governance_notes)
select 'United States–Canada Freight Corridor',us.id,ca.id,'active','RGL Phase I governed freight corridor'
from wim.markets us,wim.markets ca where us.country_code='US' and ca.country_code='CA'
on conflict (origin_market_id,destination_market_id,name) do update set status='active';

insert into wim.trade_corridors(name,origin_market_id,destination_market_id,status,governance_notes)
select 'United States–Mexico Freight Corridor',us.id,mx.id,'active','RGL Phase I governed freight corridor'
from wim.markets us,wim.markets mx where us.country_code='US' and mx.country_code='MX'
on conflict (origin_market_id,destination_market_id,name) do update set status='active';

insert into wim.trade_corridors(name,origin_market_id,destination_market_id,status,governance_notes)
select 'United States–Jamaica Multimodal Corridor',us.id,jm.id,'proposed','RGL Phase II Caribbean corridor'
from wim.markets us,wim.markets jm where us.country_code='US' and jm.country_code='JM'
on conflict (origin_market_id,destination_market_id,name) do update set status='proposed';

insert into wim.trade_corridors(name,origin_market_id,destination_market_id,status,governance_notes)
select 'United States–Dominican Republic Multimodal Corridor',us.id,dr.id,'proposed','RGL Phase II Caribbean corridor'
from wim.markets us,wim.markets dr where us.country_code='US' and dr.country_code='DO'
on conflict (origin_market_id,destination_market_id,name) do update set status='proposed';

insert into wim.trade_corridors(name,origin_market_id,destination_market_id,status,governance_notes)
select 'United States–Saint Lucia Multimodal Corridor',us.id,sl.id,'proposed','RGL Phase II Caribbean corridor'
from wim.markets us,wim.markets sl where us.country_code='US' and sl.country_code='LC'
on conflict (origin_market_id,destination_market_id,name) do update set status='proposed';

with org as (select id from wim.organizations where lower(legal_name)=lower('Robert Global Logistics LLC') limit 1), cs as (
 select tc.id from wim.trade_corridors tc join wim.markets om on om.id=tc.origin_market_id join wim.markets dm on dm.id=tc.destination_market_id
 where om.country_code='US' and dm.country_code in ('CA','MX','JM','DO','LC'))
insert into wim.organization_trade_corridor_memberships(id,organization_id,trade_corridor_id,corridor_role,participation_status,provenance)
select nextval('wim.organization_trade_corridor_memberships_id_seq'),org.id,cs.id,'logistics_provider','active',jsonb_build_object('source','RGL-WIM activation') from org cross join cs
on conflict (organization_id,trade_corridor_id,corridor_role) do update set participation_status='active',updated_at=now();

insert into rgl.wim_corridor_links(rgl_corridor_id,wim_trade_corridor_id,status)
select rc.id,tc.id,'active' from rgl.corridors rc join wim.trade_corridors tc on (
 (rc.code='RGL-R1-CUSM' and tc.name in ('United States–Canada Freight Corridor','United States–Mexico Freight Corridor')) or
 (rc.code='RGL-CAR-JAM' and tc.name='United States–Jamaica Multimodal Corridor') or
 (rc.code='RGL-CAR-DOM' and tc.name='United States–Dominican Republic Multimodal Corridor') or
 (rc.code='RGL-CAR-LCA' and tc.name='United States–Saint Lucia Multimodal Corridor'))
on conflict (rgl_corridor_id,wim_trade_corridor_id) do update set status='active';

create table if not exists rgl.access_memberships (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('executive','operator','dispatcher','auditor','carrier','shipper')),
 status text not null default 'active' check (status in ('active','suspended','revoked')),
 organization_id uuid references rgl.organizations(id),
 scope jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,role,organization_id)
);
alter table rgl.access_memberships enable row level security;

grant usage on schema rgl to authenticated;
grant select on rgl.access_memberships to authenticated;
create policy rgl_access_memberships_self_select on rgl.access_memberships for select to authenticated using ((select auth.uid())=user_id);

create policy rgl_shipments_internal_select on rgl.shipments for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_orders_internal_select on rgl.orders for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_corridors_internal_select on rgl.corridors for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_projects_internal_select on rgl.projects for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_tracking_internal_select on rgl.tracking_events for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_incidents_internal_select on rgl.incidents for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_delivery_internal_select on rgl.delivery_evidence for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','dispatcher','auditor')));
create policy rgl_invoices_internal_select on rgl.invoices for select to authenticated using (exists(select 1 from rgl.access_memberships m where m.user_id=(select auth.uid()) and m.status='active' and m.role in ('executive','operator','auditor')));

grant select on rgl.shipments,rgl.orders,rgl.corridors,rgl.projects,rgl.tracking_events,rgl.incidents,rgl.delivery_evidence,rgl.invoices to authenticated;
grant select on rgl.control_tower_shipments,rgl.control_tower_kpis to authenticated;
