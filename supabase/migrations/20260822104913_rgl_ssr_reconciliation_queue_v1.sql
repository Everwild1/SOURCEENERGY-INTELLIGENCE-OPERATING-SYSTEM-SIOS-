alter table rgl.spatial_registry_links add column if not exists ssr_registry_designation text;
alter table rgl.spatial_registry_links add column if not exists ssr_cube_uid text;
alter table rgl.spatial_registry_links add column if not exists ssr_anchor_address text;
alter table rgl.spatial_registry_links add column if not exists reconciliation_status text not null default 'pending' check(reconciliation_status in ('pending','matched','rejected','needs_review'));
alter table rgl.spatial_registry_links add column if not exists reconciliation_confidence numeric check(reconciliation_confidence between 0 and 1);

create table if not exists rgl.spatial_reconciliation_queue (
 id uuid primary key default gen_random_uuid(),
 spatial_link_id uuid not null references rgl.spatial_registry_links(id) on delete cascade,
 candidate_registry_designation text,
 candidate_cube_uid text,
 candidate_anchor_address text,
 match_method text,
 confidence numeric check(confidence between 0 and 1),
 evidence_reference text,
 review_status text not null default 'pending' check(review_status in ('pending','approved','rejected','needs_review')),
 reviewer_notes text,
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(spatial_link_id,candidate_cube_uid,candidate_anchor_address)
);
alter table rgl.spatial_reconciliation_queue enable row level security;
revoke all on rgl.spatial_reconciliation_queue from anon,authenticated;

update rgl.spatial_registry_links
set ssr_registry_designation='Codex 411 / Registry Entry 411.IX-01',
    reconciliation_status='needs_review',
    source_reference=coalesce(source_reference,'') || case when coalesce(source_reference,'')='' then '' else ' | ' end || 'SSR_Phase_XVII_Cross_Reference_Index / Registry Entry 411.IX-01',
    provenance=provenance || jsonb_build_object('ssr_authority','Codex 411','ssr_registry_entry','411.IX-01','uid_scheme','deterministic_sha256_cube_uid','anchor_address_scheme','canonical_spatial_address','drive_source_document','SSR_Phase_XVII_Cross_Reference_Index')
where source_system='sourceenergy_spatial_registry' and spatial_registry_id is null;

create or replace view rgl.spatial_reconciliation_status with (security_invoker=true) as
select s.id,s.entity_type,s.entity_id,s.spatial_registry_id,s.ssr_registry_designation,s.ssr_cube_uid,s.ssr_anchor_address,
       s.reconciliation_status,s.reconciliation_confidence,s.jurisdiction_code,s.source_reference
from rgl.spatial_registry_links s;
revoke all on rgl.spatial_reconciliation_status from anon,authenticated;
