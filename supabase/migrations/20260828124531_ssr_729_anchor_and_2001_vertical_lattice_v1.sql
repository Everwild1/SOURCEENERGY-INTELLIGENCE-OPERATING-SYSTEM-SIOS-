create table if not exists ecology.ssr_dca_729_registry (
  sequence_no integer primary key check(sequence_no between 1 and 729),
  working_anchor_id text not null unique,
  dca_address text not null unique,
  ternary_address text not null unique check(ternary_address ~ '^[0-2]{6}$'),
  dca_layer integer not null check(dca_layer between 1 and 9),
  local_position integer not null check(local_position between 1 and 81),
  l1 smallint not null check(l1 between 0 and 2),
  l2 smallint not null check(l2 between 0 and 2),
  x1 smallint not null check(x1 between 0 and 2),
  x2 smallint not null check(x2 between 0 and 2),
  x3 smallint not null check(x3 between 0 and 2),
  x4 smallint not null check(x4 between 0 and 2),
  canonical_anchor_address text,
  anchor_tile_id text,
  latitude double precision check(latitude is null or latitude between -90 and 90),
  longitude double precision check(longitude is null or longitude between -180 and 180),
  mapping_status text not null default 'unmapped' check(mapping_status in ('unmapped','candidate','evidence_supported','verified_reference','promoted','rejected')),
  evidence_reference text,
  authority_reference text not null default 'MC-411 / Scroll 411',
  namespace_boundary text not null default 'DCA machine coordinate is distinct from canonical SSR spatial address; no one-to-one mapping is asserted without explicit concordance.',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table ecology.ssr_dca_729_registry enable row level security;
drop policy if exists ssr_dca_729_registry_service_role_all on ecology.ssr_dca_729_registry;
create policy ssr_dca_729_registry_service_role_all on ecology.ssr_dca_729_registry for all to service_role using (true) with check (true);

with src as (
  select n+1 as sequence_no,
         ((n/243)%3)::smallint as l1,
         ((n/81)%3)::smallint as l2,
         ((n/27)%3)::smallint as x1,
         ((n/9)%3)::smallint as x2,
         ((n/3)%3)::smallint as x3,
         (n%3)::smallint as x4
  from generate_series(0,728) n
), encoded as (
  select *, l1::text||l2::text||x1::text||x2::text||x3::text||x4::text as ternary_address
  from src
)
insert into ecology.ssr_dca_729_registry(sequence_no,working_anchor_id,dca_address,ternary_address,dca_layer,local_position,l1,l2,x1,x2,x3,x4,evidence_reference)
select sequence_no,
       'Cube-'||lpad(sequence_no::text,3,'0'),
       'DCA:'||substring(ternary_address,1,2)||':'||substring(ternary_address,3,4),
       ternary_address,
       (l1*3+l2)+1,
       (x1*27+x2*9+x3*3+x4)+1,
       l1,l2,x1,x2,x3,x4,
       'Google Drive: 729-Cube Autonomy Scorecard / DCA-729 Registry'
from encoded
on conflict(sequence_no) do update set
  working_anchor_id=excluded.working_anchor_id,
  dca_address=excluded.dca_address,
  ternary_address=excluded.ternary_address,
  dca_layer=excluded.dca_layer,
  local_position=excluded.local_position,
  l1=excluded.l1,l2=excluded.l2,x1=excluded.x1,x2=excluded.x2,x3=excluded.x3,x4=excluded.x4,
  evidence_reference=excluded.evidence_reference,
  updated_at=now();

create table if not exists ecology.ssr_vertical_2001_layers (
  z_index integer primary key check(z_index between -1000 and 1000),
  z_label text not null unique,
  altitude_m integer not null,
  relative_position text not null check(relative_position in ('below_surface','surface','above_surface')),
  increment_m integer not null default 3 check(increment_m=3),
  authority_reference text not null default 'MC-411 / Scroll 411',
  created_at timestamptz not null default now()
);
alter table ecology.ssr_vertical_2001_layers enable row level security;
drop policy if exists ssr_vertical_2001_layers_service_role_all on ecology.ssr_vertical_2001_layers;
create policy ssr_vertical_2001_layers_service_role_all on ecology.ssr_vertical_2001_layers for all to service_role using (true) with check (true);

insert into ecology.ssr_vertical_2001_layers(z_index,z_label,altitude_m,relative_position)
select z,
       'Z'||case when z>=0 then '+' else '-' end||lpad(abs(z)::text,4,'0'),
       z*3,
       case when z<0 then 'below_surface' when z=0 then 'surface' else 'above_surface' end
from generate_series(-1000,1000) z
on conflict(z_index) do update set z_label=excluded.z_label,altitude_m=excluded.altitude_m,relative_position=excluded.relative_position;

create extension if not exists pgcrypto;

create or replace view ecology.ssr_729x2001_address_space as
select a.sequence_no,a.working_anchor_id,a.dca_address,a.ternary_address,a.dca_layer,a.local_position,
       a.canonical_anchor_address,a.anchor_tile_id,a.latitude,a.longitude,a.mapping_status,
       z.z_index,z.z_label,z.altitude_m,
       case when a.canonical_anchor_address is not null
            then a.canonical_anchor_address||'@'||z.z_label
            else null end as canonical_cube_address,
       case when a.canonical_anchor_address is not null
            then encode(digest(a.canonical_anchor_address||'@'||z.z_label,'sha256'),'hex')
            else null end as deterministic_cube_uid,
       case when a.canonical_anchor_address is not null then 'addressable' else 'awaiting_anchor_concordance' end as addressability_status
from ecology.ssr_dca_729_registry a cross join ecology.ssr_vertical_2001_layers z;

create or replace view ecology.ssr_architecture_capacity as
select
  (select count(*) from ecology.ssr_dca_729_registry) as anchor_columns,
  (select count(*) from ecology.ssr_vertical_2001_layers) as vertical_layers,
  (select count(*) from ecology.ssr_dca_729_registry) * (select count(*) from ecology.ssr_vertical_2001_layers) as governed_spatial_assets,
  (select count(*) from ecology.ssr_dca_729_registry where canonical_anchor_address is not null) as mapped_anchor_columns,
  (select count(*) from ecology.ssr_dca_729_registry where canonical_anchor_address is not null) * (select count(*) from ecology.ssr_vertical_2001_layers) as currently_addressable_assets;

