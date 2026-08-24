-- SEC-PROD-01 phase 1: privilege hardening only.
-- PostGIS is currently extension-managed in public; do not relocate or mutate
-- extension-owned spatial_ref_sys in this migration.

revoke execute on function public.st_estimatedextent(text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text,boolean) from public, anon, authenticated;

grant execute on function public.st_estimatedextent(text,text) to service_role;
grant execute on function public.st_estimatedextent(text,text,text) to service_role;
grant execute on function public.st_estimatedextent(text,text,text,boolean) to service_role;

comment on extension postgis is 'SEC-PROD-01: extension remains in public pending validated compatibility-preserving relocation plan; client EXECUTE on SECURITY DEFINER st_estimatedextent overloads is explicitly revoked.';