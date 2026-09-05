# Deprecated Schema Identifier Governance

## Control objective
Prevent obsolete or ambiguous database identifiers from being reintroduced into the SourceEnergy Intelligence Operating System contract.

## Deprecated identifier
`adapter_code`

`adapter_code` is not part of the current authoritative SourceEnergy schema contract and must not be added merely for backward compatibility with stale callers.

## Canonical subsystem identifiers
Use the identifier defined by the owning subsystem contract. Current examples include:

- SourceEnergy One: `adapter_key`
- OEL command boundary: `adapter_command_id` and the registered client contract
- SourceEnergy Insurance: `insurance_adapter_system_id`

These identifiers are not interchangeable. A caller must bind to the contract of the subsystem it invokes.

## CI enforcement
Run `scripts/check-deprecated-schema-identifiers.sh` during CI. The check fails if `adapter_code` is introduced into tracked application or migration content.

## Change governance
Any proposal to restore a deprecated identifier requires an explicit architecture decision, migration plan, compatibility analysis, and approval before implementation. Do not alter the authoritative Supabase schema solely to satisfy a stale client assumption.
