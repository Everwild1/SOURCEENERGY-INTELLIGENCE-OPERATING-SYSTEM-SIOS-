alter table dhn_consent.consents
  add constraint consents_revocation_consistency
  check ((status = 'revoked' and revoked_at is not null) or status <> 'revoked');

create index if not exists idx_dhn_consents_actor_status
  on dhn_consent.consents(actor_id, status, effective_at desc);
create index if not exists idx_dhn_consents_grantee_purpose
  on dhn_consent.consents(grantee_ref, purpose, status);
create index if not exists idx_dhn_authz_actor_time
  on dhn_consent.authorization_decisions(actor_id, decided_at desc);
create index if not exists idx_dhn_authz_correlation
  on dhn_consent.authorization_decisions(correlation_id);
