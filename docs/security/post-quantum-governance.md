# SourceEnergy Post-Quantum Cryptographic Governance Layer (PQ-CGL)

Status: Phase IV engineering baseline

## Control objective

SIOS SHALL remain cryptographically agile: business logic must not depend permanently on a single public-key algorithm. Quantum readiness is measured through discovery, classification, migration, verification, and governed retirement.

## Current control domains

- `pqc.algorithm_registry` — approved, transitional, deprecated, and prohibited algorithms.
- `pqc.crypto_assets` — cryptographic inventory and confidentiality horizon.
- `pqc.crypto_policies` — Q1/Q2/Q3 assurance profiles.
- `pqc.key_registry` — key metadata and external KMS/HSM references only; private keys are prohibited.
- `pqc.migration_register` — governed migration backlog.
- `pqc.vendor_registry` — vendor PQC readiness evidence.
- `pqc.verification_events` — append-oriented verification evidence.
- `evidence.signature_envelopes` — cryptographic evidence associated with governed objects.

## Migration doctrine

1. Discover cryptographic dependencies before replacement.
2. Separate API-key modernization, Auth signing-key modernization, and true PQC migration.
3. Do not represent RSA, ECC, ECDSA, ECDH, or ES256 as post-quantum secure.
4. Prefer algorithm policy indirection over hard-coded cryptographic choices.
5. Do not store private signing/key-establishment material in ordinary application tables.
6. Long-duration trust, custody, treasury, and IP provenance records receive Q3/Q2 treatment as applicable.
7. Cryptographic verification is evidence; it is not institutional authorization.

## Supabase transition boundary

Legacy JWT-based `anon` and `service_role` API keys are migration dependencies. Client applications should move to publishable keys and controlled backends to independently rotatable secret keys after dependency validation. Supabase Auth signing-key modernization is a separate track and must not be labeled PQC while the supported signing algorithms remain classical.

## CI gate

Pull requests affecting PQ-CGL migrations or this policy must pass the PQ-CGL contract workflow. The gate verifies schemas, RLS, algorithm baseline, service-role-only control-plane policies, absence of private-key columns in the key registry, and security-invoker behavior for verification-event recording.

## Human governance boundary

No cryptographic verification, score, signature, automated policy result, or ledger anchor independently creates legal, fiduciary, regulatory, banking, custody, investment, or institutional authority. Material decisions require accountable human authorization and controlling external evidence where applicable.
