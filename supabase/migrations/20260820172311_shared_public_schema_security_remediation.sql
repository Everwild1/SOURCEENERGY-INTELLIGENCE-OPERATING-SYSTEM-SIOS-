alter table public.codex_registry enable row level security;
alter table public.scroll_library enable row level security;
alter table public.dominion_grid enable row level security;
alter table public.ssr_spatial_registry enable row level security;
alter table public.anchor_tiles enable row level security;

revoke all on public.codex_registry from anon, authenticated;
revoke all on public.scroll_library from anon, authenticated;
revoke all on public.dominion_grid from anon, authenticated;
revoke all on public.ssr_spatial_registry from anon, authenticated;
revoke all on public.anchor_tiles from anon, authenticated;

grant all on public.codex_registry to service_role;
grant all on public.scroll_library to service_role;
grant all on public.dominion_grid to service_role;
grant all on public.ssr_spatial_registry to service_role;
grant all on public.anchor_tiles to service_role;

revoke execute on function public.st_estimatedextent(text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.st_estimatedextent(text,text) to service_role;
grant execute on function public.st_estimatedextent(text,text,text) to service_role;
grant execute on function public.st_estimatedextent(text,text,text,boolean) to service_role;

comment on table public.codex_registry is 'RLS/default-deny hardened on 2026-08-20 shared backend security remediation; explicit access policies required before client exposure.';
comment on table public.scroll_library is 'RLS/default-deny hardened on 2026-08-20 shared backend security remediation; explicit access policies required before client exposure.';
comment on table public.dominion_grid is 'RLS/default-deny hardened on 2026-08-20 shared backend security remediation; explicit access policies required before client exposure.';
comment on table public.ssr_spatial_registry is 'RLS/default-deny hardened on 2026-08-20 shared backend security remediation; explicit access policies required before client exposure.';
comment on table public.anchor_tiles is 'RLS/default-deny hardened on 2026-08-20 shared backend security remediation; explicit access policies required before client exposure.';
