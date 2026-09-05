alter table sourcecubes.spatial_concordance add column if not exists canonical_use_status text not null default 'NONCANONICAL_LEGACY_CONTROL';
update sourcecubes.spatial_concordance set canonical_use_status='NONCANONICAL_LEGACY_CONTROL';
comment on table sourcecubes.spatial_concordance is 'Legacy/noncanonical control created before DCA namespace reconciliation. DCA addresses are governance machine coordinates for 729 scorecard/AnchorTile rows, not geographic coordinates. Do not use this table to infer DCA-to-lat/lon mappings.';

create table if not exists sourcecubes.anchor_tile_bindings (
  binding_id uuid primary key default gen_random_uuid(),
  anchor_tile_id text references public.anchor_tiles(anchor_tile_id) on delete restrict,
  anchor_candidate_id uuid references ecology.ssr_anchor_candidate_registry(id) on delete restrict,
  dca_sequence_no integer references ecology.ssr_dca_729_registry(sequence_no) on delete restrict,
  canonical_address text,
  cube_uid text,
  latitude double precision,
  longitude double precision,
  z_index integer,
  authority_state text not null default 'CANDIDATE',
  binding_status text not null default 'PENDING_PROMOTION',
  evidence_reference text,
  namespace_note text not null default 'DCA is a machine/governance coordinate for the 729 scorecard row and does not replace the canonical spatial address.',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((anchor_tile_id is not null)::int + (anchor_candidate_id is not null)::int = 1),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);
create unique index if not exists sourcecubes_anchor_tile_unique_idx on sourcecubes.anchor_tile_bindings(anchor_tile_id) where anchor_tile_id is not null;
create unique index if not exists sourcecubes_anchor_candidate_unique_idx on sourcecubes.anchor_tile_bindings(anchor_candidate_id) where anchor_candidate_id is not null;

update sourcecubes.anchor_tile_bindings b set canonical_address=c.canonical_address,cube_uid=c.cube_uid,latitude=c.latitude,longitude=c.longitude,z_index=c.z_index,authority_state='CANDIDATE',binding_status='W3W_VALIDATED_PROMOTION_BLOCKED',evidence_reference=c.source_reference,updated_at=now()
from ecology.ssr_anchor_candidate_registry c where b.anchor_candidate_id=c.id and c.id='d9da0740-b856-489d-bc61-a213e001b478'::uuid;

insert into sourcecubes.anchor_tile_bindings(anchor_candidate_id,canonical_address,cube_uid,latitude,longitude,z_index,authority_state,binding_status,evidence_reference)
select c.id,c.canonical_address,c.cube_uid,c.latitude,c.longitude,c.z_index,'CANDIDATE','W3W_VALIDATED_PROMOTION_BLOCKED',c.source_reference
from ecology.ssr_anchor_candidate_registry c
where c.id='d9da0740-b856-489d-bc61-a213e001b478'::uuid
and not exists (select 1 from sourcecubes.anchor_tile_bindings b where b.anchor_candidate_id=c.id);

update sourcecubes.canonical_address_contract
set cube_uid_pattern='SHA-256(canonical spatial address string) or other governed canonical UID rule defined by SSR; DCA address is not embedded as a geographic coordinate',
    horizontal_registry='public.anchor_tiles (authoritative); ecology.ssr_anchor_candidate_registry (pre-promotion evidence lane)',
    vertical_registry='ecology.ssr_vertical_11001_layers',
    w3w_registry='public.anchor_tiles / ecology.ssr_anchor_candidate_registry / ecology.ssr_w3w_validation_log',
    coordinate_policy='Canonical horizontal geography is carried by AnchorTile latitude/longitude plus validated What3Words surface address. DCA six-trit addresses are separate machine/governance coordinates for 729 scorecard rows and must not be interpreted as latitude/longitude.',
    binding_policy='A SourceCube binds a canonical spatial address/AnchorTile to a vertical z-index. A DCA sequence may optionally reference the related 729 governance row/AnchorTile, but DCA does not define geographic position.',
    status='CONTROLLED_CANONICAL_CORRECTED',updated_at=now()
where contract_id='SC-CAC-001';

update sourcecubes.integration_spec
set horizontal_registry='public.anchor_tiles',
    namespace_policy='Canonical spatial authority is AnchorTile/SSR: validated What3Words + latitude/longitude + canonical vertical z-index. DCA-729 six-trit addresses are machine/governance coordinates for the 729 scorecard rows / AnchorTiles; they do not replace MC-411-style canonical spatial addresses and are not latitude/longitude coordinates. DCA association is optional metadata on a SourceCube binding.',
    updated_at=now()
where spec_id='SC-SSR-001';

update sourcecubes.concordance_control_status
set global_binding_status='BLOCKED_PENDING_ANCHOR_TILE_PROMOTION',
    blocking_reason='DCA-to-latitude/longitude concordance is not the canonical requirement. Drive governance establishes DCA as a machine coordinate for 729 scorecard/AnchorTile rows, distinct from spatial namespaces. Canonical SourceCube geography must come from validated/promoted AnchorTiles. One candidate (Norman Manley International Airport) has API-validated What3Words and elevation but remains promotion-blocked pending provenance/hash controls.',
    assessed_at=now()
where control_id='SC-CONCORDANCE-001';

comment on table sourcecubes.anchor_tile_bindings is 'Canonical SourceCubes horizontal/spatial binding lane. Authoritative rows bind public.anchor_tiles; candidate rows bind ecology.ssr_anchor_candidate_registry until promotion. DCA linkage is optional governance metadata only.';
