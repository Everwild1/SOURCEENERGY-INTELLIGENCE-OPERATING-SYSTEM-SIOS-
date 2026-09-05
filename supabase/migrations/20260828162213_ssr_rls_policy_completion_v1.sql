drop policy if exists service_role_all on public.spatial_cubes;
create policy service_role_all on public.spatial_cubes for all to service_role using (true) with check (true);

drop policy if exists service_role_all on ssr_ingest.anchor_tiles_stage;
create policy service_role_all on ssr_ingest.anchor_tiles_stage for all to service_role using (true) with check (true);

drop policy if exists service_role_all on ssr_ingest.batches;
create policy service_role_all on ssr_ingest.batches for all to service_role using (true) with check (true);
