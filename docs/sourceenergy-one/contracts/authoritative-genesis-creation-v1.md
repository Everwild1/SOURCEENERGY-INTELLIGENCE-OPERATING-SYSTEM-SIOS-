# Authoritative Genesis Creation Boundary v1

Status: Phase 1 governed contract

## Purpose

This contract defines the only service-mediated boundary for persisting an authoritative SourceEnergy One Genesis package after the experience reaches Genesis Ready.

## Deployed RPC

`sourceenergy_one.create_genesis_package(impact_report_id, approval_id, schema_version, package, package_hash)`

The RPC is `SECURITY DEFINER`, has a controlled `search_path`, and is executable only by `service_role`. `public`, `anon`, and `authenticated` have no execute privilege.

## Mandatory gates

The RPC fails closed unless all of the following are true:

1. The referenced impact report exists and has status `approved`.
2. The referenced Genesis approval exists, belongs to that impact report, and has decision `approve`.
3. A human authorizing actor is recorded by `actor_ref` or `actor_id`.
4. A non-empty consent receipt is recorded on the approval.
5. The immutable package subject matches the approved impact report subject.
6. The package attests `human_approved=true`.
7. The package contains a non-empty `authorization_attestation`.
8. The package contains a non-empty `jurisdiction`.
9. The supplied package hash is a 64-character hexadecimal SHA-256 representation.
10. Raw Purpose Discovery material is not embedded under `raw_purpose_discovery` or `responses`.

On success the RPC inserts one `genesis_packages` record and one `genesis_package_created` audit event.

## Package contract

The application-side authoritative package additionally validates purpose provenance, approved MVP artifact/hash, impact report/hash, consent references, Codex24 package version, authorizing actor, authorization attestation, append-only `prior_genesis_id`, and the impact horizons `present`, `1`, `5`, `10`, `25`, `50`, and `100` years. A deterministic SHA-256 provenance hash is generated over the canonical payload.

## Separation of authority

Genesis readiness is not Genesis creation. Codex24 synthesis is advisory. Human approval is mandatory. Direct browser/client writes are prohibited. SourceCube, SETC Genesis, HeartBeatID, financial/institutional execution, and consequential production adapters are not activated by this boundary.

The optional `setc_genesis_ref` and `sourcecube_context_ref` fields remain unset until separately governed downstream integrations are authorized.
