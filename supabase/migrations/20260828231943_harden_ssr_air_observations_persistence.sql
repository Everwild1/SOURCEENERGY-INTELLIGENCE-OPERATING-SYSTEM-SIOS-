grant usage on schema ecology to service_role;
grant select, insert, update, delete on table ecology.ssr_air_observations to service_role;

alter table ecology.ssr_air_observations
  drop constraint if exists ssr_air_observations_latitude_check,
  drop constraint if exists ssr_air_observations_longitude_check,
  drop constraint if exists ssr_air_observations_pressure_level_hpa_check;

alter table ecology.ssr_air_observations
  add constraint ssr_air_observations_latitude_check check (latitude between -90 and 90),
  add constraint ssr_air_observations_longitude_check check (longitude between -180 and 180),
  add constraint ssr_air_observations_pressure_level_hpa_check check (pressure_level_hpa is null or pressure_level_hpa > 0);

comment on table ecology.ssr_air_observations is 'Validated atmospheric evidence associated with SSR coordinates. Environmental evidence only; does not alter canonical SSR identity, W3W address, EGM96 elevation, or Z assignment.';
comment on column ecology.ssr_air_observations.variables is 'Validated scalar atmospheric values keyed by source variable code.';
comment on column ecology.ssr_air_observations.units is 'Units keyed by source variable code.';
comment on column ecology.ssr_air_observations.retrieval_metadata is 'NASA/MERRA-2 provenance, grid resolution, indices, quality gate, and retrieval context.';
