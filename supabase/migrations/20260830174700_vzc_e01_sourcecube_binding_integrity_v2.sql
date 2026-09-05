alter table vzc.spatial_bindings
  add constraint vzc_spatial_sourcecube_binding_fk
  foreign key (sourcecube_binding_id) references sourcecubes.cube_bindings(binding_id) on delete restrict;

alter table vzc.organization_bindings
  add constraint vzc_org_sourcecube_candidate_fk
  foreign key (sourcecube_candidate_id) references sourcecubes.organization_candidates(candidate_id) on delete restrict;

create index vzc_spatial_sourcecube_binding_fk_idx on vzc.spatial_bindings(sourcecube_binding_id) where sourcecube_binding_id is not null;
create index vzc_org_sourcecube_candidate_fk_idx on vzc.organization_bindings(sourcecube_candidate_id) where sourcecube_candidate_id is not null;

comment on column vzc.spatial_bindings.ssr_registry_id is 'Optional external/shared SSR registry UUID reference. No FK is declared because the current SSR schema does not expose a single canonical registry table; prefer sourcecubes.cube_bindings when available.';
