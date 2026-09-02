-- SECURITY ADVISOR REMEDIATION — PHASE 1 (audit findings S1, S2, S3)
-- S1: spatial_ref_sys client exposure; S2: st_estimatedextent RPC exposure;
-- S3: pin search_path on 11 flagged functions.
-- Retained by design: public.setc_media_my_capabilities(),
-- public.setc_media_publication_ready(uuid) — intentional authenticated RPCs.
-- Internal hardening only; confers/verifies nothing externally.

-- S1. public.spatial_ref_sys — remove client API exposure
revoke all on table public.spatial_ref_sys from anon, authenticated;

do $$
begin
  alter table public.spatial_ref_sys enable row level security;
exception
  when insufficient_privilege then
    raise notice 'spatial_ref_sys: not owner; RLS skipped (client access already revoked).';
end $$;

-- S2. st_estimatedextent — revoke all overloads from client roles
revoke execute on function public.st_estimatedextent(text, text) from anon, authenticated;
revoke execute on function public.st_estimatedextent(text, text, text) from anon, authenticated;
revoke execute on function public.st_estimatedextent(text, text, text, boolean) from anon, authenticated;

-- S3. Pin search_path on the 11 flagged functions (every overload)
do $$
declare
  r record;
begin
  for r in
    select n.nspname as sch,
           p.proname  as fn,
           pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where (n.nspname, p.proname) in (
      ('ecology','ssr_z_label'),
      ('ecology','ssr_candidate_z_guard'),
      ('ecology','ssr_z_from_egm96_elevation'),
      ('ecology','block_ssr_air_event_audit_mutation'),
      ('ecology','block_ssr_air_delivery_receipt_mutation'),
      ('ecology','ssr_air_policy_matches_event'),
      ('ecology','block_ssr_air_event_decision_mutation'),
      ('ecology','block_ssr_air_event_action_audit_mutation'),
      ('ecology','block_ssr_air_cross_domain_validation_audit_mutation'),
      ('ecology','block_ssr_sea_validation_job_audit_mutation'),
      ('sourcecubes','reconcile_vertical_evidence')
    )
  loop
    execute format(
      'alter function %I.%I(%s) set search_path = %I, public, pg_catalog',
      r.sch, r.fn, r.args, r.sch
    );
  end loop;
end $$;
