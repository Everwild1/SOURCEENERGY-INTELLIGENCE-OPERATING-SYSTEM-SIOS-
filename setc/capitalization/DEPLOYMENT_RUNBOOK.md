# Capitalization Block Deployment Runbook

## Target environment

Deploy the Capitalization Block to the **SourceEnergy command backend**. Keep the dedicated Source Coin environment separate. Capitalization stores Source Coin request and confirmation references only; it does not host or mutate the Source Coin ledger.

## Required roles

- database migration operator
- SETC/SIOS platform owner
- security reviewer
- capital/treasury domain owner
- compliance/legal reviewer
- independent release approver
- auditor/evidence custodian

No single person should both request and approve production activation.

## Preflight

1. Create branch `feat/capitalization-control-plane`.
2. Copy this overlay into the repository root.
3. Run:

   ```bash
   python -m compileall -q setc/capitalization
   python -m unittest discover -s setc/capitalization/tests -p 'test_*.py' -v
   python setc/capitalization/artifact_checks.py
   ```

4. Record the commit SHA and current database migration head.
5. Export a schema-only backup and an approved recovery snapshot.
6. Confirm migrations target the SourceEnergy command backend, not the Source Coin project.
7. Confirm no client, log, migration, or seed contains raw account numbers, credentials, private keys, custody keys, or service-role keys.
8. Review `SECURITY_REVIEW_NOTES.md` and resolve the existing `public.spatial_ref_sys` RLS decision separately.

## Apply sequence

Apply in order:

1. `012_capitalization_foundation.sql`
2. `013_capitalization_treasury_interbank.sql`
3. `014_capitalization_settlement_governance.sql`
4. `015_capitalization_api_projection_security.sql`
5. Optional and separately approved: `016_optional_live_page_registry_seed.sql`

Do not run migration 016 automatically. It normalizes current public-page labels as target-only registry entries and should be applied only when communications/governance accepts the revised disclosure model.

## Post-migration validation

1. Run `setc/capitalization/validation.sql`.
2. Run Supabase security and performance advisors.
3. Confirm every `capitalization` and `capitalization_api` base table has RLS enabled.
4. Confirm `anon` and `authenticated` have no internal `capitalization` table privileges.
5. Confirm both release gates remain disabled:
   - `PRODUCTION_SETTLEMENT = false`
   - `PUBLIC_LIVE_NETWORK_CLAIMS = false`
6. Confirm no production settlement exists beyond `APPROVED`.
7. Confirm no public directory row has `VERIFIED_LIVE` while the public gate is disabled.
8. Confirm public projection tables contain no account, balance, commitment, settlement, endpoint, credential, or evidence-document fields.
9. Store validation output as release evidence.

## Data API exposure

Do not expose the internal `capitalization` schema.

Only after security review:

1. Add `capitalization_api` to Supabase Data API exposed schemas.
2. Confirm only `SELECT` is granted to `anon` and `authenticated` on:
   - `capitalization_api.network_directory`
   - `capitalization_api.dashboard_metrics`
   - `capitalization_api.api_contract_versions`
3. Confirm RLS policies limit reads to published rows.
4. Keep refresh and governance functions outside the public API schema and executable only by trusted server-side roles.
5. Never expose `service_role` to a browser or third-party frontend.

## Optional registry normalization

After migration 016:

- expected entries: 26
- expected relationship state: `TARGET`
- expected connectivity: `NOT_CONNECTED`
- expected verification: `UNVERIFIED`
- expected public claim: `REGISTRY_TARGET`
- expected verified live count: 0

Review the public page against `PUBLIC_PAGE_COPY.md` before publishing.

## Sandbox and test activation

1. Create only sandbox or test endpoints with opaque credential references.
2. Establish mTLS/signature identity for adapters.
3. Create compliance and approval evidence.
4. Exercise WIM request ingestion without mutating WIM trade state.
5. Exercise Source Coin confirmation ingestion without mutating Source Coin ledger state.
6. Exercise external fiat confirmations using synthetic references.
7. Test duplicate events, retries, race conditions, timeouts, reversals, and reconciliation variances.
8. Demonstrate that production submission fails while the gate is disabled.

## Production-settlement authorization

Production remains NO-GO until independent reviews are complete. When governance authorizes production:

```sql
SELECT *
FROM capitalization.authorize_release_gate(
    'PRODUCTION_SETTLEMENT',
    true,
    '<authorization-reference>',
    '<evidence-reference>',
    '<authorized-actor-reference>',
    '<bounded rationale and approved scope>'
);
```

Required evidence includes exact code SHA, migration head, environment, approved adapters, legal/compliance disposition, security audit, key/custody design, rollback exercise, residual-risk register, and authorization scope.

## Public live-claim authorization

This is separate from settlement activation. Enable only after every institution/node to be labeled live has verified relationship, institution, and production-connectivity evidence:

```sql
SELECT *
FROM capitalization.authorize_release_gate(
    'PUBLIC_LIVE_NETWORK_CLAIMS',
    true,
    '<communications-and-governance-authorization>',
    '<verification-evidence-package>',
    '<authorized-actor-reference>',
    '<approved public-claim scope>'
);

SELECT *
FROM capitalization.refresh_public_network_projection(
    '<authorized-refresh-actor>'
);
```

Review the resulting public directory before publication.

## Emergency restriction

A safe emergency action is to disable a release gate with evidence, suspend the affected relationship/corridor/node, stop adapters, and preserve all records. Do not delete history.

```sql
SELECT *
FROM capitalization.authorize_release_gate(
    'PRODUCTION_SETTLEMENT',
    false,
    '<emergency-authorization-reference>',
    '<incident-evidence-reference>',
    '<authorized-actor-reference>',
    '<incident scope and rationale>'
);
```

## Rollback strategy

These migrations are additive. Do not use destructive rollback in production.

1. Disable both release gates.
2. Remove `capitalization_api` from exposed schemas if public access must stop.
3. Stop application writers and adapters.
4. Preserve audit, lineage, confirmation, and reconciliation records.
5. Correct defects through a new forward migration.
6. Restore only from an approved recovery snapshot when governance declares database recovery necessary.
7. Re-run validation and advisors before reopening any capability.
