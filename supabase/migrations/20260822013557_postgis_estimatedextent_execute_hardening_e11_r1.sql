-- Recovered from production supabase_migrations.schema_migrations.
revoke execute on function public.st_estimatedextent(text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text,boolean) from public, anon, authenticated;
