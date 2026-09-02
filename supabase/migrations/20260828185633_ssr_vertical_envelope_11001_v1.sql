update ecology.ssr_vertical_assignment_standard
set min_z=-4000,
    max_z=7000,
    notes='Earth operational envelope: -12,000 m to +21,000 m relative to EGM96 at 3 m resolution (11,001 layers). Covers deepest ocean and tropopause design envelope while preserving existing Z addresses.'
where standard_code='SSR-Z-EGM96-3M-V1';

create or replace function ecology.ssr_z_from_egm96_elevation(p_elevation_m numeric)
returns integer language plpgsql immutable as $$
declare v_z integer;
begin
 if p_elevation_m is null then return null; end if;
 v_z := round(p_elevation_m / 3.0)::integer;
 if v_z < -4000 or v_z > 7000 then raise exception 'Elevation maps outside SSR Earth operational Z range: %', v_z; end if;
 return v_z;
end $$;

alter table ecology.ssr_vertical_2001_layers drop constraint if exists ssr_vertical_2001_layers_z_index_check;
alter table ecology.ssr_vertical_2001_layers add constraint ssr_vertical_2001_layers_z_index_check check (z_index between -4000 and 7000);

alter table ecology.ssr_anchor_candidate_registry drop constraint if exists ssr_anchor_candidate_registry_z_index_check;
alter table ecology.ssr_anchor_candidate_registry add constraint ssr_anchor_candidate_registry_z_index_check check (z_index is null or z_index between -4000 and 7000);

alter table public.spatial_cubes drop constraint if exists spatial_cubes_z_index_check;
alter table public.spatial_cubes add constraint spatial_cubes_z_index_check check (z_index between -4000 and 7000);

insert into ecology.ssr_vertical_2001_layers(z_index,z_label,altitude_m,relative_position)
select z,
       'Z'||case when z>=0 then '+' else '-' end||lpad(abs(z)::text,4,'0'),
       z*3,
       case when z<0 then 'below_surface' when z=0 then 'surface' else 'above_surface' end
from generate_series(-4000,7000) z
on conflict(z_index) do update set
  z_label=excluded.z_label,
  altitude_m=excluded.altitude_m,
  relative_position=excluded.relative_position;

comment on table ecology.ssr_vertical_2001_layers is 'Legacy table name retained for compatibility. Active SSR Earth operational vertical lattice now contains 11,001 3 m layers from Z-4000 (-12 km) through Z+7000 (+21 km), EGM96 datum.';

create or replace view ecology.ssr_vertical_operational_layers as
select z_index,z_label,altitude_m,relative_position,increment_m,authority_reference,created_at
from ecology.ssr_vertical_2001_layers
where z_index between -4000 and 7000;

create or replace view ecology.ssr_architecture_capacity as
select
  (select count(*) from ecology.ssr_dca_729_registry) as anchor_columns,
  (select count(*) from ecology.ssr_vertical_operational_layers) as vertical_layers,
  (select count(*) from ecology.ssr_dca_729_registry) * (select count(*) from ecology.ssr_vertical_operational_layers) as governed_spatial_assets,
  (select count(*) from ecology.ssr_dca_729_registry where canonical_anchor_address is not null) as mapped_anchor_columns,
  (select count(*) from ecology.ssr_dca_729_registry where canonical_anchor_address is not null) * (select count(*) from ecology.ssr_vertical_operational_layers) as currently_addressable_assets;

create or replace view ecology.ssr_729x2001_address_space as
select a.sequence_no,a.working_anchor_id,a.dca_address,a.ternary_address,a.dca_layer,a.local_position,
       a.canonical_anchor_address,a.anchor_tile_id,a.latitude,a.longitude,a.mapping_status,
       z.z_index,z.z_label,z.altitude_m,
       case when a.canonical_anchor_address is not null then a.canonical_anchor_address||'@'||z.z_label else null end as canonical_cube_address,
       case when a.canonical_anchor_address is not null then encode(digest(a.canonical_anchor_address||'@'||z.z_label,'sha256'),'hex') else null end as deterministic_cube_uid,
       case when a.canonical_anchor_address is not null then 'addressable' else 'awaiting_anchor_concordance' end as addressability_status
from ecology.ssr_dca_729_registry a cross join ecology.ssr_vertical_operational_layers z;
