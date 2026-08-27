# DHN E11-R1 Production Migration Reconciliation

Status: release-control artifact
Target Supabase project: `veopccdltsklczlmdbri` (`SourceEnergy-command-backend`)
Generated from the production migration ledger on 2026-08-22.

## Purpose

The production database is currently ahead of the SQL files committed in this repository. This manifest records the authoritative production migration inventory needed for DHN release-readiness reconciliation. It does **not** claim that missing SQL bodies have been reconstructed.

## Repository migrations already present

- 20260822000138 — create_setc_heartbeat_biometric_namespace
- 20260822000416 — setc_heartbeat_events_audit_and_continuity
- 20260822001521 — setc_heartbeat_device_attestation_binding
- 20260822002121 — setc_heartbeat_audit_device_integrity_binding
- 20260822002529 — ecosystem_rls_service_role_baseline

## Production migrations requiring repository parity

- 20260822002906 — postgis_estimatedextent_rpc_hardening
- 20260822011202 — dhn_e01_domain_schema_baseline
- 20260822011222 — dhn_e01_foreign_key_indexes
- 20260822011347 — dhn_e02_identity_credential_lifecycle
- 20260822011457 — dhn_e03_consent_authorization_engine
- 20260822011740 — dhn_e04_clinical_interoperability
- 20260822011851 — dhn_e05_heartbeatid_adapter
- 20260822012050 — dhn_e06_rencat_telemetry_ingestion
- 20260822012123 — dhn_e06_performance_cleanup
- 20260822012241 — dhn_e07_audit_attestation_service
- 20260822012502 — dhn_e08_external_ledger_anchor_boundary
- 20260822012630 — dhn_e09_settlement_source_coin_boundary
- 20260822012846 — dhn_e10_observability_security_controls
- 20260822012950 — dhn_e11_acceptance_test_registry

## Release rule

Production promotion remains NO-GO until the exact SQL migration bodies for the production-only versions above are captured in `supabase/migrations/` (or the migration history is otherwise reconciled using an approved Supabase workflow), CI verifies replay on a clean environment, and the E11 acceptance suite is rerun.

## Security blocker

The Supabase security advisor still reports shared PostGIS/public-schema findings: `public.spatial_ref_sys` lacks RLS; PostGIS remains installed in `public`; and `public.st_estimatedextent` SECURITY DEFINER overloads are executable by `anon`/`authenticated`. These are shared-platform findings, not DHN schema findings, but they remain E11 release blockers until remediated or formally risk-accepted.

## Governance boundary

Do not fabricate historical migration SQL from schema state and label it as the original migration. If exact bodies cannot be recovered, create a reviewed baseline/reconciliation migration strategy and document the provenance explicitly.
