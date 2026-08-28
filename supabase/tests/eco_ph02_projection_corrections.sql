begin;

-- Valid correction and supersession chain.
insert into ecology.projection_corrections
  (id,target_kind,target_key,correction_type,reason,source_authority,evidence_reference)
values
  ('00000000-0000-0000-0000-00000000c201','regenerative_projection','test:projection:1','corrects','Correct projected impact','WIM','evidence:test:1');

insert into ecology.projection_corrections
  (target_kind,target_key,correction_type,supersedes_correction_id,reason,source_authority,authority_reference)
values
  ('regenerative_projection','test:projection:1','supersedes','00000000-0000-0000-0000-00000000c201','Supersede prior correction','WIM','authority:test:1');

-- Invalid target kind must fail closed.
do $$ begin
  begin
    insert into ecology.projection_corrections(target_kind,target_key,correction_type,reason,source_authority)
    values ('unknown','test:bad','corrects','Bad target','WIM');
    raise exception 'expected invalid target kind to fail';
  exception when check_violation then null; end;
end $$;

-- Blank reason must fail closed.
do $$ begin
  begin
    insert into ecology.projection_corrections(target_kind,target_key,correction_type,reason,source_authority)
    values ('impact_lineage','test:bad','corrects','   ','WIM');
    raise exception 'expected blank reason to fail';
  exception when check_violation then null; end;
end $$;

-- Only supersedes may point at a prior correction.
do $$ begin
  begin
    insert into ecology.projection_corrections(target_kind,target_key,correction_type,supersedes_correction_id,reason,source_authority)
    values ('impact_lineage','test:bad','corrects','00000000-0000-0000-0000-00000000c201','Invalid chain','WIM');
    raise exception 'expected invalid correction chain to fail';
  exception when check_violation then null; end;
end $$;

-- Service role is append-only at the privilege boundary.
do $$ begin
  if has_table_privilege('service_role','ecology.projection_corrections','UPDATE') then
    raise exception 'service_role must not have UPDATE on correction history';
  end if;
  if has_table_privilege('service_role','ecology.projection_corrections','DELETE') then
    raise exception 'service_role must not have DELETE on correction history';
  end if;
  if not has_table_privilege('service_role','ecology.projection_corrections','SELECT, INSERT') then
    raise exception 'service_role requires SELECT and INSERT on correction history';
  end if;
end $$;

rollback;
