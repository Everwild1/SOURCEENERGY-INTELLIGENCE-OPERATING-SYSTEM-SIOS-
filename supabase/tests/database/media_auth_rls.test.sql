begin;

-- Synthetic UUIDs simulate JWT subjects only. They are not production identities.
-- Supabase's current RLS testing guidance supports setting the authenticated role
-- and request.jwt.claim.sub for database-level authorization tests.

select plan(10);

select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_media_content'),
  'media content has RLS enabled'
);

select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_media_events'),
  'media events have RLS enabled'
);

select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='setc_media_outbox'),
  'media outbox has RLS enabled'
);

select is((select count(*)::bigint from auth.users), 0::bigint,
  'database contract does not require production Auth users');

select is(media_access.assert_test_principal('TEST_CONTRIBUTOR'),
  '10000000-0000-4000-8000-000000000001'::uuid,
  'synthetic contributor principal is stable');

select media_access.test_set_principal('TEST_CONTRIBUTOR');
set local role authenticated;
select is(auth.uid(), '10000000-0000-4000-8000-000000000001'::uuid,
  'authenticated contributor JWT subject is simulated');
reset role;

select media_access.test_set_principal('TEST_OUTSIDER');
set local role authenticated;
select ok(not media_access.has_permission(null,'media.publish'),
  'unassigned principal cannot publish without organization authority');
reset role;

select ok(
  exists(select 1 from media_access.permissions where permission_code='media.publish'),
  'media.publish permission exists'
);
select ok(
  exists(select 1 from media_access.permissions where permission_code='media.approve'),
  'media.approve permission exists separately from publish'
);
select ok(
  exists(select 1 from media_access.permissions where permission_code='media.fact_validate'),
  'fact validation permission exists separately from approval'
);

select * from finish();
rollback;
