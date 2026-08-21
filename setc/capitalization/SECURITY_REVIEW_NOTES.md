# Security Review Notes

## 1. Existing command-backend RLS finding

A live schema inspection identified `public.spatial_ref_sys` with Row Level Security disabled. This is an extension-managed PostGIS reference table and is outside the Capitalization migrations. It has **not** been changed automatically.

The platform owner must decide whether the table is exposed through the Data API and which roles genuinely require access. Enabling RLS without an intentional policy can block required reads; leaving an exposed table without RLS can permit unintended access depending on grants.

Decision sequence:

1. Inspect current grants and Data API exposure.
2. Confirm whether browser/API clients need the table.
3. Revoke unnecessary grants.
4. Define the minimum read policy if client access is required.
5. Then enable RLS:

   ```sql
   ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
   ```

6. Re-run Supabase security and performance advisors.

Do not apply that statement blindly without the policy/grant decision.

## 2. Schema exposure

- Keep `capitalization` unexposed.
- Expose `capitalization_api` only after review.
- Grant public clients `SELECT` only on explicitly published projection tables.
- Never put a `SECURITY DEFINER` function in an exposed schema.
- Every security-definer function in this package has a fixed `search_path` and is restricted to trusted server roles.

## 3. Service-role boundary

The Supabase `service_role` bypasses RLS and must never be used by a browser, embedded in a build, logged, sent to a client, or shared with an external adapter. Frontends call an authorized server layer that applies policy, rate limits, audit, and step-up authentication.

## 4. Sensitive financial data

Do not store:

- raw bank-account numbers
- private keys or seed phrases
- custody keys
- PINs or passwords
- API secrets
- service-role keys
- unmasked payment credentials
- full regulated identity documents in general-purpose JSON

Use approved secret/custody/document systems and store only opaque references such as `vault:...`, `token:...`, `masked:...`, or `provider:...`.

## 5. External institution claims

`financial_institutions`, `institution_relationships`, and `network_nodes` are internal governance records. A record can become public only through the sanitized projection. The `VERIFIED_LIVE` label requires all of the following:

- `relationship_state = LIVE`
- relationship agreement and evidence
- institution `verification_status = VERIFIED`
- active production node with endpoint, evidence, and verification timestamp
- enabled `PUBLIC_LIVE_NETWORK_CLAIMS` gate

## 6. Finality and ledger authority

- Capitalization cannot self-confer finality.
- Source Coin finality must originate from `SOURCE_COIN_DOMAIN`.
- Fiat finality must originate from the identified regulated external rail/provider.
- WIM requests settlement but does not own finality.
- Corrections are compensating records; settled history is never overwritten or deleted.

## 7. Event security

- Adapter endpoints require mTLS plus detached signature verification.
- Every event has a globally unique event ID, correlation ID, producer, contract/version, and payload hash.
- Inbox uniqueness prevents duplicate processing records.
- Idempotency keys protect commands and settlement instructions.
- Replays, signature failures, stale timestamps, unsupported versions, and authority mismatch must be rejected and audited.

## 8. Required independent reviews

Before production activation, obtain and archive:

- application and database security audit
- legal and regulatory review by jurisdiction/use case
- AML/KYB/sanctions control review
- privacy and data-retention review
- external adapter/counterparty due diligence
- key, certificate, custody, rotation, and recovery procedures
- incident response and rollback exercise evidence
- residual-risk register and accountable disposition
