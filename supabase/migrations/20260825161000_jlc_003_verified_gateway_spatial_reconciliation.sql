-- JLC-003: evidence-gated gateway and spatial reconciliation.
create table if not exists jlc.spatial_reconciliation (
  reconciliation_code text primary key,
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  jlc_node_code text not null references jlc.nodes(node_code) on delete cascade,
  rgl_infrastructure_node_id uuid,
  match_basis text not null,
  confidence numeric(5,4) not null check (confidence between 0 and 1),
  verification_state text not null check (verification_state in ('PENDING_VERIFICATION','VERIFIED_REFERENCE','REJECTED','ARCHIVED')),
  latitude numeric,
  longitude numeric,
  source_authority text,
  source_reference text,
  created_at timestamptz not null default now(),
  unique(jlc_node_code,rgl_infrastructure_node_id)
);
alter table jlc.spatial_reconciliation enable row level security;
grant select,insert,update,delete on jlc.spatial_reconciliation to service_role;
revoke all on jlc.spatial_reconciliation from anon,authenticated;
create policy service_role_all on jlc.spatial_reconciliation for all to service_role using (true) with check (true);

insert into jlc.rgl_asset_links(link_code,corridor_code,jlc_node_code,rgl_entity_type,rgl_entity_id,relationship_role,verification_state,evidence_reference)
select 'JLC-RGL-NODE-KIN-AIR-001','JLC-001',null,'INFRASTRUCTURE_NODE',id,'AIR_GATEWAY_REFERENCE','VERIFIED_REFERENCE','RGL:IATA-KIN'
from rgl.infrastructure_nodes where iata_code='KIN' and verification_status='verified' on conflict do nothing;
insert into jlc.rgl_asset_links(link_code,corridor_code,jlc_node_code,rgl_entity_type,rgl_entity_id,relationship_role,verification_state,evidence_reference)
select 'JLC-RGL-NODE-MBJ-AIR-001','JLC-001',null,'INFRASTRUCTURE_NODE',id,'AIR_GATEWAY_REFERENCE','VERIFIED_REFERENCE','RGL:IATA-MBJ'
from rgl.infrastructure_nodes where iata_code='MBJ' and verification_status='verified' on conflict do nothing;
insert into jlc.spatial_reconciliation(reconciliation_code,corridor_code,jlc_node_code,rgl_infrastructure_node_id,match_basis,confidence,verification_state,latitude,longitude,source_authority,source_reference)
select 'JLC-SPATIAL-KINGSTON-PORT-001','JLC-001','JLC-NODE-KINGSTON-WESTLANDS',id,'JLC gateway name/locality reconciled to verified RGL Port of Kingston canonical node; Westlands sub-location remains separately evidence-gated',0.9000,'VERIFIED_REFERENCE',latitude,longitude,source_authority,source_reference
from rgl.infrastructure_nodes where name='Port of Kingston / Kingston Container Terminal' and verification_status='verified'
on conflict do nothing;
update jlc.nodes n set latitude=r.latitude::double precision,longitude=r.longitude::double precision,external_spatial_reference='RGL:'||r.id::text,updated_at=now()
from rgl.infrastructure_nodes r
where n.node_code='JLC-NODE-KINGSTON-WESTLANDS' and r.name='Port of Kingston / Kingston Container Terminal' and r.verification_status='verified';
