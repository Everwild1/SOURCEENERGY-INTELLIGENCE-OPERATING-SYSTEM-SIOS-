# PQC Phase V — Operational Cryptographic Migration

Status: CONTROLLED MIGRATION RUNBOOK

## Objective
Move SIOS from cryptographic inventory/governance into controlled operational migration without service interruption or premature claims of post-quantum readiness.

## Supabase API-key migration
Current Supabase guidance separates API-key modernization from JWT-signing-key modernization.

1. Keep legacy keys active during dependency discovery.
2. Replace public/client legacy `anon` usage with `sb_publishable_*` keys.
3. Replace backend `service_role` usage with independently rotatable `sb_secret_*` keys.
4. New secret keys are backend-only and bypass RLS; never expose them in browser/mobile/public code.
5. For pg_net/database webhooks, send new secret keys in the `apikey` header, not `Authorization: Bearer`.
6. Store database-originated secret-key material in an approved secret store such as Supabase Vault; do not hardcode it in SQL.
7. Edge Functions using new keys must be reviewed separately because new opaque keys are not JWTs.
8. Do not deactivate legacy keys until client, backend, CI/CD, webhook, cron, worker, mobile/desktop and integration dependencies are verified migrated.
9. Deactivation is a separate human-authorized production gate.

## JWT signing-key migration
This is a separate workstream from API-key modernization.

- Inventory any component that validates JWTs directly against the legacy shared secret.
- Inventory Edge Functions relying on legacy Verify JWT behavior.
- Move toward Supabase rotatable signing keys only after dependency verification.
- Current Supabase asymmetric signing options (RSA/ECC) improve rotation and key isolation but are not post-quantum cryptography.
- Therefore Auth modernization must never be recorded as PQC completion.

## PQC boundary
PQC Phase V prioritizes long-duration evidence and authorization objects rather than replacing every platform primitive at once.

Priority pilots:
1. IPBCM provenance evidence envelope.
2. Covenant Trust / ScrollBank long-duration attestations.
3. High-value institutional authorization evidence.
4. Vendor PQC readiness attestations.

## Evidence-envelope pilot contract
Every pilot object must preserve:
- object identifier and type
- cryptographic digest and digest algorithm
- signer identity and credential reference
- signature algorithm/version
- timestamp
- crypto policy identifier
- verification status and engine
- optional chain anchor
- evidence metadata

Private keys are prohibited from ordinary application/database tables. Only public fingerprints/references and external KMS/HSM references may be registered.

## Migration gates
V0 Inventory dependency
V1 Publishable-key client migration
V2 Secret-key backend migration
V3 Legacy-key zero-dependency evidence
V4 JWT signing-key modernization
V5 IPBCM evidence-envelope pilot
V6 Trust/ScrollBank Q3 pilot
V7 Vendor attestation coverage
V8 Independent verification
V9 Human authorization for legacy retirement

## Completion rule
A component is not PQC-ready merely because it uses modern Supabase keys or asymmetric JWT signing. PQC-ready status requires the applicable SourceEnergy crypto policy, standardized post-quantum mechanism where required, verification evidence, and accountable governance approval.
