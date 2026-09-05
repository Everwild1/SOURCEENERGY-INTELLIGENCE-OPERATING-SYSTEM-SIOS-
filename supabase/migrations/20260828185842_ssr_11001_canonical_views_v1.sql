create or replace view ecology.ssr_vertical_11001_layers as
select * from ecology.ssr_vertical_operational_layers;

create or replace view ecology.ssr_729x11001_address_space as
select * from ecology.ssr_729x2001_address_space;

comment on view ecology.ssr_vertical_11001_layers is 'Canonical SSR Earth operational vertical lattice: 11,001 layers, 3 m increments, EGM96 datum, Z-4000 through Z+7000.';
comment on view ecology.ssr_729x11001_address_space is 'Canonical 729-column x 11,001-layer SSR Earth operational address space. Legacy 729x2001 view retained for backward compatibility.';

create or replace view ecology.ssr_vertical_envelope_status as
select
  'SSR-Z-EGM96-3M-V1'::text as standard_code,
  min(z_index) as min_z,
  max(z_index) as max_z,
  min(altitude_m) as min_altitude_m,
  max(altitude_m) as max_altitude_m,
  count(*)::bigint as vertical_layers,
  729::bigint as anchor_columns,
  (729::bigint * count(*)::bigint) as governed_spatial_assets
from ecology.ssr_vertical_11001_layers;
