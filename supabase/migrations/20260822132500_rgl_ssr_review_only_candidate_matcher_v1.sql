create table if not exists rgl.spatial_match_evidence (
 id uuid primary key default gen_random_uuid(),
 spatial_link_id uuid not null references rgl.spatial_registry_links(id) on delete cascade,
 evidence_type text not null check(evidence_type in ('authoritative_coordinate','official_identifier','registry_reference','operator_attestation','source_document')),
 authority text not null,
 reference text,
 latitude numeric,
 longitude numeric,
 observed_at timestamptz,
 verification_status text not null default 'pending' check(verification_status in ('pending','verified','rejected')),
 provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
alter table rgl.spatial_match_evidence enable row level security;
revoke all on rgl.spatial_match_evidence from anon,authenticated;

create or replace function rgl.generate_ssr_match_candidates(p_max_distance_m numeric default 5000)
returns integer
language plpgsql
security invoker
set search_path = pg_catalog, public, rgl
as $$
declare v_count integer;
begin
  if p_max_distance_m <= 0 or p_max_distance_m > 50000 then
    raise exception 'Invalid max distance % meters', p_max_distance_m;
  end if;

  insert into rgl.spatial_reconciliation_queue(
    spatial_link_id,candidate_registry_designation,candidate_cube_uid,candidate_anchor_address,
    match_method,confidence,evidence_reference,review_status,reviewer_notes
  )
  select
    s.id,
    s.ssr_registry_designation,
    null,
    a.w3w_address,
    'authoritative_coordinate_proximity_review_only',
    greatest(0, 1 - (st_distance(
      st_setsrid(st_makepoint(e.longitude::double precision,e.latitude::double precision),4326)::geography,
      a.geom::geography
    ) / p_max_distance_m))::numeric,
    coalesce(e.reference,e.authority),
    'needs_review',
    'Candidate only. Do not promote without human review and authoritative AnchorTile provenance.'
  from rgl.spatial_registry_links s
  join lateral (
    select e1.* from rgl.spatial_match_evidence e1
    where e1.spatial_link_id=s.id and e1.evidence_type='authoritative_coordinate' and e1.verification_status='verified'
      and e1.latitude is not null and e1.longitude is not null
    order by e1.created_at desc limit 1
  ) e on true
  join public.anchor_tiles a on st_dwithin(
    st_setsrid(st_makepoint(e.longitude::double precision,e.latitude::double precision),4326)::geography,
    a.geom::geography,
    p_max_distance_m
  )
  where s.reconciliation_status in ('pending','needs_review')
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function rgl.generate_ssr_match_candidates(numeric) from public,anon,authenticated;

create or replace view rgl.spatial_match_readiness with (security_invoker=true) as
select s.id,s.entity_type,s.entity_id,s.reconciliation_status,
       count(e.id) filter(where e.verification_status='verified') verified_evidence_count,
       count(e.id) filter(where e.evidence_type='authoritative_coordinate' and e.verification_status='verified') verified_coordinate_count,
       case when exists(select 1 from rgl.spatial_match_evidence e2 where e2.spatial_link_id=s.id and e2.evidence_type='authoritative_coordinate' and e2.verification_status='verified' and e2.latitude is not null and e2.longitude is not null)
            then 'ready_for_candidate_generation' else 'awaiting_authoritative_coordinates' end readiness
from rgl.spatial_registry_links s
left join rgl.spatial_match_evidence e on e.spatial_link_id=s.id
group by s.id,s.entity_type,s.entity_id,s.reconciliation_status;
revoke all on rgl.spatial_match_readiness from anon,authenticated;
