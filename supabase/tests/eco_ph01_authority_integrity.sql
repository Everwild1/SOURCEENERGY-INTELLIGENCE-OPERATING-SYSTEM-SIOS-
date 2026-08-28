begin;

-- Valid canonical mapping succeeds.
insert into ecology.object_references (
  domain, object_type, object_id, source_authority, posture
) values (
  'source_coin', 'contract_test', 'eco-ph01-valid', 'SOURCE_COIN', 'reference_only'
);

-- Invalid source authority must fail closed.
do $$
begin
  begin
    insert into ecology.object_references (
      domain, object_type, object_id, source_authority, posture
    ) values (
      'source_coin', 'contract_test', 'eco-ph01-invalid', 'ECOLOGY', 'reference_only'
    );
    raise exception 'ECO-PH-01 failure: invalid source_coin/ECOLOGY mapping was accepted';
  exception
    when check_violation then null;
  end;
end $$;

-- Ecology cannot masquerade as an external authority.
do $$
begin
  begin
    insert into ecology.object_references (
      domain, object_type, object_id, source_authority, posture
    ) values (
      'external_authority', 'contract_test', 'eco-ph01-external-invalid', ' ECOLOGY ', 'reference_only'
    );
    raise exception 'ECO-PH-01 failure: ECOLOGY external authority was accepted';
  exception
    when check_violation then null;
  end;
end $$;

-- Named external authority remains referenceable.
insert into ecology.object_references (
  domain, object_type, object_id, source_authority, posture
) values (
  'external_authority', 'contract_test', 'eco-ph01-external-valid', 'TEST_REGULATED_AUTHORITY', 'reference_only'
);

rollback;
