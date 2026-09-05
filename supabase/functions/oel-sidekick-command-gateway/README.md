# oel-sidekick-command-gateway

Trusted external command boundary for the SourceEnergy × Sidekick Organizational Execution Layer.

## Security posture

- External machine-to-machine endpoint; Supabase platform JWT verification is disabled.
- Trust is established by application-level HMAC-SHA256 verification plus OEL registry policy.
- Gateway fails closed if `OEL_SIDEKICK_SHARED_SECRET` or the database connection is unavailable.
- `sidekick-oel` is initially restricted to the SourceEnergy Group OID, an explicit action allowlist, and a C2 maximum control level.
- C3–C6 consequential actions remain behind accountable human authorization.

## Required environment

```text
OEL_SIDEKICK_SHARED_SECRET=<secret; never commit>
SUPABASE_DB_URL=<managed runtime database connection>
```

Do not place real values in repository files.

## Signature

Compute `payload_hash = SHA256(JSON.stringify(payload))` as lowercase hex.

Join the following values with a literal newline, preserving empty `resource_id` / `channel_identity` positions:

```text
client_code
command_id
idempotency_key
nonce
request_timestamp
correlation_id
trace_id
setc_org_oid
action
resource_type
resource_id
requested_control_level
actor_external_ref
channel_identity
payload_hash
```

Then compute:

```text
signature = hex(HMAC-SHA256(OEL_SIDEKICK_SHARED_SECRET, canonical_string))
```

Send it in `x-oel-signature`.

## Commissioning

See `docs/oel/OEL-COMMISSION-001.md`. Production use is not authorized merely because the Edge Function is ACTIVE. Commissioning requires secret provisioning, verified actor/channel mappings, replay/idempotency tests, and demonstrated C3 human-gate behavior.
