-- ECO-PH-01 additive hardening. Deployed to SourceEnergy command backend.
-- Preserves ECO-E04 service-only/RLS posture and does not modify PostGIS.

alter table ecology.object_references
  add constraint object_references_domain_source_authority_chk
  check (
    (domain = 'setc' and source_authority = 'SETC') or
    (domain = 'source_block' and source_authority = 'SOURCE_BLOCK') or
    (domain = 'wim' and source_authority = 'WIM') or
    (domain = 'cruds' and source_authority = 'CRUDS') or
    (domain = 'hei' and source_authority = 'HEI') or
    (domain = 'gsc' and source_authority = 'GSC') or
    (domain = 'rgl' and source_authority = 'RGL') or
    (domain = 'capitalization' and source_authority = 'CAPITALIZATION') or
    (domain = 'source_coin' and source_authority = 'SOURCE_COIN') or
    (domain = 'external_authority' and btrim(source_authority) <> '' and upper(btrim(source_authority)) <> 'ECOLOGY')
  );

comment on constraint object_references_domain_source_authority_chk on ecology.object_references is
  'ECO-PH-01: fail-closed canonical domain-to-source-authority mapping; external authorities must be named and cannot be ECOLOGY.';
