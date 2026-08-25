create schema if not exists auth;
create schema if not exists media_access;

create table if not exists auth.users (id uuid primary key,email text);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;

create table if not exists media_access.permissions (permission_code text primary key