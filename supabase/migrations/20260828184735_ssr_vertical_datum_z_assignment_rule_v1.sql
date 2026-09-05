create table if not exists ecology.ssr_vertical_assignment_standard (
  standard_code text primary key,
  horizontal_crs text not null,
  vertical_datum text not null,
  z_origin_definition text not null,
  layer_height_m numeric not null check (layer_height_m > 0),
  quantization_rule text not null,
  min_z integer not null,
  max_z integer not null,
  status text not null default 'active',
  effective_at timestamptz not null default now(),
  notes text
);
insert into ecology.ssr_vertical_assignment_standard(standard_code,horizontal_crs,vertical_datum,z_origin_definition,layer_height_m,quantization_rule,min_z,max_z,status,notes)
values ('SSR-Z-EGM96-3M-V1','WGS84','EGM96','Z=0 is elevation 0 metres relative to the EGM96 mean-sea-level/geoid datum; local ground does not reset the origin.',3,'nearest_layer_center: z_index = round(elevation_m_egm96 / 3.0); positive above datum, negative below datum',-1000,1000,'active','Do not assign Z from terrain category, facility type, or W3W alone. Elevation evidence relative to EGM96 is required.')
on conflict (standard_code) do update set horizontal_crs=excluded.horizontal_crs,vertical_datum=excluded.vertical_datum,z_origin_definition=excluded.z_origin_definition,layer_height_m=excluded.layer_height_m,quantization_rule=excluded.quantization_rule,min_z=excluded.min_z,max_z=excluded.max_z,status='active',notes=excluded.notes;

alter table ecology.ssr_anchor_candidate_registry add column if not exists elevation_m_egm96 numeric;
alter table ecology.ssr_anchor_candidate_registry add column if not exists elevation_evidence_reference text;
alter table ecology.ssr_anchor_candidate_registry add column if not exists z_assignment_standard text default 'SSR-Z-EGM96-3M-V1';

create or replace function ecology.ssr_z_from_egm96_elevation(p_elevation_m numeric)
returns integer language plpgsql immutable as $$
declare v_z integer;
begin
 if p_elevation_m is null then return null; end if;
 v_z := round(p_elevation_m / 3.0)::integer;
 if v_z < -1000 or v_z > 1000 then raise exception 'Elevation maps outside SSR Z range: %', v_z; end if;
 return v_z;
end $$;

create or replace function ecology.ssr_z_label(p_z integer)
returns text language sql immutable as $$ select case when p_z is null then null when p_z >= 0 then 'Z+'||lpad(p_z::text,4,'0') else 'Z-'||lpad(abs(p_z)::text,4,'0') end $$;

create or replace function ecology.ssr_candidate_z_guard()
returns trigger language plpgsql as $$
begin
 new.z_assignment_standard := 'SSR-Z-EGM96-3M-V1';
 if new.elevation_m_egm96 is null then
   new.z_index := null;
   new.canonical_address := null;
 elsif new.elevation_evidence_reference is null or btrim(new.elevation_evidence_reference)='' then
   raise exception 'EGM96 elevation evidence is required before Z assignment';
 else
   new.z_index := ecology.ssr_z_from_egm96_elevation(new.elevation_m_egm96);
   if new.w3w_address is not null then new.canonical_address := new.w3w_address || '@' || ecology.ssr_z_label(new.z_index); end if;
 end if;
 return new;
end $$;
drop trigger if exists trg_ssr_candidate_z_guard on ecology.ssr_anchor_candidate_registry;
create trigger trg_ssr_candidate_z_guard before insert or update of elevation_m_egm96,elevation_evidence_reference,w3w_address,z_index,canonical_address on ecology.ssr_anchor_candidate_registry for each row execute function ecology.ssr_candidate_z_guard();

update ecology.ssr_anchor_candidate_registry
set z_index=null, canonical_address=null, z_assignment_standard='SSR-Z-EGM96-3M-V1',
    blocker_reason=case when elevation_m_egm96 is null then 'Authoritative EGM96-relative elevation required for deterministic 3 m Z assignment before canonical promotion.' else blocker_reason end;

alter table public.anchor_tiles alter column vertical_datum set default 'EGM96';
alter table public.spatial_cubes alter column vertical_datum set default 'EGM96';
alter table ssr_ingest.anchor_tiles_stage alter column vertical_datum set default 'EGM96';

comment on column ecology.ssr_anchor_candidate_registry.z_index is 'Deterministic 3 m layer index relative to EGM96 datum. Z=0 is sea-level datum, not local ground.';
comment on column public.spatial_cubes.z_index is 'SSR 3 m vertical layer relative to EGM96 datum; positive above datum, negative below datum.';
