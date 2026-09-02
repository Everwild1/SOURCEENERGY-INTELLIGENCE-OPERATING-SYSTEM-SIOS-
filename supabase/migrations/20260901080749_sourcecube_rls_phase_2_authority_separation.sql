create schema if not exists private;

create or replace function private.sourcecube_has_active_context(p_min_assurance text default 'standard')
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from sourceenergy_one.access_contexts ac
      where ac.actor_id = (select auth.uid())
        and (ac.expires_at is null or ac.expires_at > now())
        and case p_min_assurance
          when 'institutional' then ac.assurance_level = 'institutional'
          when 'elevated' then ac.assurance_level in ('elevated','institutional')
          else ac.assurance_level in ('standard','elevated','institutional')
        end
    );
$$;

create or replace function private.sourcecube_has_verified_actor()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from sourceenergy_one.actor_identities ai
      where ai.auth_user_id = (select auth.uid())
        and ai.status = 'active'
        and ai.assurance_level in ('verified','strong_verified')
    );
$$;

create or replace function private.sourcecube_has_authority(p_assignment_id uuid, p_authority_type text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  with ctx as (
    select ac.organization_ref, ac.assurance_level
    from sourceenergy_one.access_contexts ac
    where ac.actor_id = (select auth.uid())
      and (ac.expires_at is null or ac.expires_at > now())
  ), eligible as (
    select sa.authority_type, sa.authority_state
    from public.sourcecube_authorities sa
    where sa.assignment_id = p_assignment_id
      and (sa.valid_from is null or sa.valid_from <= now())
      and (sa.valid_until is null or sa.valid_until > now())
      and (
        sa.subject_user_id = (select auth.uid())
        or (
          sa.subject_organization_oid is not null
          and exists (
            select 1 from ctx
            where ctx.organization_ref = sa.subject_organization_oid
          )
        )
      )
  )
  select case
    when (select auth.uid()) is null then false
    when p_authority_type = 'VIEW_ASSIGNMENT' then
      (select private.sourcecube_has_active_context('standard'))
      and exists (
        select 1 from eligible
        where authority_state in ('VERIFIED','CONDITIONAL')
          and authority_type in ('VIEW_ASSIGNMENT','MANAGE_ASSIGNMENT','GRANT_AUTHORITY','EXECUTE_GOVERNED_ACTION')
      )
    when p_authority_type = 'MANAGE_ASSIGNMENT' then
      (select private.sourcecube_has_active_context('elevated'))
      and exists (
        select 1 from eligible
        where authority_state = 'VERIFIED'
          and authority_type = 'MANAGE_ASSIGNMENT'
      )
    when p_authority_type = 'GRANT_AUTHORITY' then
      (select private.sourcecube_has_active_context('institutional'))
      and (select private.sourcecube_has_verified_actor())
      and exists (
        select 1 from eligible
        where authority_state = 'VERIFIED'
          and authority_type = 'GRANT_AUTHORITY'
      )
    when p_authority_type = 'EXECUTE_GOVERNED_ACTION' then
      (select private.sourcecube_has_active_context('institutional'))
      and (select private.sourcecube_has_verified_actor())
      and exists (
        select 1 from eligible
        where authority_state = 'VERIFIED'
          and authority_type = 'EXECUTE_GOVERNED_ACTION'
      )
    else false
  end;
$$;

revoke all on schema private from public;
revoke all on function private.sourcecube_has_active_context(text) from public;
revoke all on function private.sourcecube_has_verified_actor() from public;
revoke all on function private.sourcecube_has_authority(uuid,text) from public;
grant usage on schema private to authenticated;
grant execute on function private.sourcecube_has_active_context(text) to authenticated;
grant execute on function private.sourcecube_has_verified_actor() to authenticated;
grant execute on function private.sourcecube_has_authority(uuid,text) to authenticated;

-- Registry taxonomy is visible only inside a live SourceEnergy One access context.
create policy source_cubes_authenticated_select
on public.source_cubes for select
to authenticated
using ((select private.sourcecube_has_active_context('standard')));

create policy sourcecube_assignments_authorized_select
on public.sourcecube_assignments for select
to authenticated
using ((select private.sourcecube_has_authority(id,'VIEW_ASSIGNMENT')));

create policy sourcecube_assignments_authorized_update
on public.sourcecube_assignments for update
to authenticated
using ((select private.sourcecube_has_authority(id,'MANAGE_ASSIGNMENT')))
with check ((select private.sourcecube_has_authority(id,'MANAGE_ASSIGNMENT')));

create policy sourcecube_authorities_authorized_select
on public.sourcecube_authorities for select
to authenticated
using ((select private.sourcecube_has_authority(assignment_id,'VIEW_ASSIGNMENT')));

create policy sourcecube_authorities_grant_insert
on public.sourcecube_authorities for insert
to authenticated
with check (
  (select private.sourcecube_has_authority(assignment_id,'GRANT_AUTHORITY'))
  and granted_by = (select auth.uid())
  and authority_state in ('PROPOSED','CONDITIONAL','RESTRICTED','EVIDENCE_REQUIRED')
);

create policy sourcecube_authorities_grant_update
on public.sourcecube_authorities for update
to authenticated
using ((select private.sourcecube_has_authority(assignment_id,'GRANT_AUTHORITY')))
with check (
  (select private.sourcecube_has_authority(assignment_id,'GRANT_AUTHORITY'))
  and authority_state <> 'VERIFIED'
);

create policy sourcecube_evidence_authorized_select
on public.sourcecube_evidence for select
to authenticated
using ((select private.sourcecube_has_authority(assignment_id,'VIEW_ASSIGNMENT')));

create policy sourcecube_evidence_manage_insert
on public.sourcecube_evidence for insert
to authenticated
with check (
  (select private.sourcecube_has_authority(assignment_id,'MANAGE_ASSIGNMENT'))
  and verification_state = 'PENDING'
  and verified_by is null
  and verified_at is null
);

create policy sourcecube_dependencies_authorized_select
on public.sourcecube_dependencies for select
to authenticated
using ((select private.sourcecube_has_authority(assignment_id,'VIEW_ASSIGNMENT')));

create policy sourcecube_approvals_authorized_select
on public.sourcecube_approvals for select
to authenticated
using ((select private.sourcecube_has_authority(assignment_id,'VIEW_ASSIGNMENT')));

create policy sourcecube_approvals_request_insert
on public.sourcecube_approvals for insert
to authenticated
with check (
  ((select private.sourcecube_has_authority(assignment_id,'MANAGE_ASSIGNMENT'))
    or (select private.sourcecube_has_authority(assignment_id,'EXECUTE_GOVERNED_ACTION')))
  and requested_by = (select auth.uid())
  and decision = 'PENDING'
  and decided_by is null
  and decided_at is null
);

create policy sourcecube_events_authorized_select
on public.sourcecube_events for select
to authenticated
using (
  assignment_id is not null
  and (select private.sourcecube_has_authority(assignment_id,'VIEW_ASSIGNMENT'))
);

-- Object-level grants: broad writes stay service-mediated; authenticated users receive only bounded columns.
grant select on public.source_cubes to authenticated;
grant select on public.sourcecube_assignments, public.sourcecube_authorities, public.sourcecube_evidence, public.sourcecube_dependencies, public.sourcecube_approvals, public.sourcecube_events to authenticated;

grant update (mandate, geography, effective_from, effective_until, restrictions, metadata, updated_at)
on public.sourcecube_assignments to authenticated;

grant insert (assignment_id, authority_type, subject_user_id, subject_organization_oid, authority_state, evidence_ref, granted_by, valid_from, valid_until)
on public.sourcecube_authorities to authenticated;
grant update (authority_state, evidence_ref, valid_from, valid_until)
on public.sourcecube_authorities to authenticated;

grant insert (assignment_id, evidence_type, evidence_ref, metadata)
on public.sourcecube_evidence to authenticated;

grant insert (assignment_id, action_type, requested_by, metadata)
on public.sourcecube_approvals to authenticated;

comment on function private.sourcecube_has_authority(uuid,text) is 'Fail-closed SourceCube authorization helper. VIEW, MANAGE, GRANT and EXECUTE are independent rights; creator/admin status does not imply governed execution authority.';

