create table if not exists sourcecubes.vertical_envelope_control (
  envelope_id text primary key,
  vertical_registry text not null,
  layer_count integer not null,
  min_z_index integer not null,
  max_z_index integer not null,
  min_altitude_m integer not null,
  max_altitude_m integer not null,
  increment_m integer not null,
  datum_reference text not null,
  below_datum_layers integer not null,
  datum_layers integer not null,
  above_datum_layers integer not null,
  status text not null,
  authority_reference text not null,
  verified_at timestamptz not null default now()
);

insert into sourcecubes.vertical_envelope_control(envelope_id,vertical_registry,layer_count,min_z_index,max_z_index,min_altitude_m,max_altitude_m,increment_m,datum_reference,below_datum_layers,datum_layers,above_datum_layers,status,authority_reference)
select 'SC-VE-11001','ecology.ssr_vertical_11001_layers',count(*)::int,min(z_index),max(z_index),min(altitude_m),max(altitude_m),min(increment_m),'SEA_LEVEL_DATUM_0M',count(*) filter(where altitude_m<0)::int,count(*) filter(where altitude_m=0)::int,count(*) filter(where altitude_m>0)::int,'CANONICAL_VERIFIED','SourceCubes / SSR 11,001-layer canonicalization v1'
from ecology.ssr_vertical_11001_layers
on conflict(envelope_id) do update set layer_count=excluded.layer_count,min_z_index=excluded.min_z_index,max_z_index=excluded.max_z_index,min_altitude_m=excluded.min_altitude_m,max_altitude_m=excluded.max_altitude_m,increment_m=excluded.increment_m,below_datum_layers=excluded.below_datum_layers,datum_layers=excluded.datum_layers,above_datum_layers=excluded.above_datum_layers,status=excluded.status,authority_reference=excluded.authority_reference,verified_at=now();

create table if not exists sourcecubes.canonical_address_contract (
  contract_id text primary key,
  contract_version text not null,
  cube_uid_pattern text not null,
  horizontal_registry text not null,
  vertical_registry text not null,
  w3w_registry text not null,
  coordinate_policy text not null,
  vertical_policy text not null,
  binding_policy text not null,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into sourcecubes.canonical_address_contract(contract_id,contract_version,cube_uid_pattern,horizontal_registry,vertical_registry,w3w_registry,coordinate_policy,vertical_policy,binding_policy,status) values
('SC-CAC-001','1.0','SC:{DCA_SEQUENCE}:{Z_INDEX}:{SPATIAL_REFERENCE}','ecology.ssr_dca_729_registry','ecology.ssr_vertical_11001_layers','ecology.ssr_reference_addresses','Latitude/longitude and What3Words remain evidence-backed spatial references. DCA coordinates are not inferred where canonical concordance is absent.','z_index must exist in the canonical 11,001-layer registry spanning -12,000m through +21,000m at 3m increments; negative altitude is explicitly valid and represents below-datum/subsea/subsurface space.','A SourceCube UID is a governed binding over existing SSR/DCA/vertical registries, not a parallel spatial authority. Bindings require evidence and may not fabricate missing DCA-to-coordinate concordance.','CONTROLLED_CANONICAL')
on conflict(contract_id) do update set contract_version=excluded.contract_version,cube_uid_pattern=excluded.cube_uid_pattern,horizontal_registry=excluded.horizontal_registry,vertical_registry=excluded.vertical_registry,w3w_registry=excluded.w3w_registry,coordinate_policy=excluded.coordinate_policy,vertical_policy=excluded.vertical_policy,binding_policy=excluded.binding_policy,status=excluded.status,updated_at=now();

update sourcecubes.integration_spec
set vertical_registry='ecology.ssr_vertical_11001_layers',
    namespace_policy='SourceCube UID is a governed binding over canonical SSR infrastructure. Horizontal authority: ecology.ssr_dca_729_registry. Vertical authority: ecology.ssr_vertical_11001_layers (11,001 layers, including below-sea-level/subsurface layers). What3Words/lat-long remain spatial-reference evidence and must not be inferred where concordance is absent.',
    updated_at=now()
where spec_id='SC-SSR-001';

comment on table sourcecubes.vertical_envelope_control is 'Authoritative SourceCubes vertical envelope reconciliation. Counts and limits are computed from ecology.ssr_vertical_11001_layers.';
comment on table sourcecubes.canonical_address_contract is 'Canonical SourceCube address/binding contract. SourceCubes does not create a competing spatial registry.';
