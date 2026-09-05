# OEL-COMMISSION-001 — Sidekick Trusted Gateway Commissioning Protocol

**Status:** Commissioning baseline  
**Architecture owner:** SourceEnergy Group  
**Implementation boundary:** SourceEnergy × Sidekick OEL  
**Gateway:** `oel-sidekick-command-gateway`  
**Supabase project:** `veopccdltsklczlmdbri`

## 1. Purpose

Commission the cryptographic machine-to-machine boundary between Sidekick and the SourceEnergy Organizational Execution Layer (OEL) without creating a parallel system of record or allowing Sidekick to self-authorize consequential actions.

Canonical separation:

> SourceEnergy One presents; SourceCube reasons and orchestrates; Sidekick organizes and activates; SETC/SIOS governs and records.

Governance doctrine:

> Observation ≠ inference ≠ official warning. Material decisions require accountable human authorization.

## 2. Trust boundary

`Sidekick -> signed request envelope -> Edge signature/integrity verification -> SourceEnergy actor/channel resolution -> OEL adapter registry -> governed OEL API -> policy/authorization gate -> execution or DecisionRequest -> durable receipt`

The public Edge endpoint uses application-level HMAC authentication. Platform JWT verification is intentionally disabled for this external service-to-service endpoint; this does **not** make the endpoint trusted by default. A request is trusted only after the gateway validates the configured adapter, payload hash, signature, timestamp, nonce, actor mapping, organization scope and control ceiling.

## 3. Registered adapter

Client code: `sidekick-oel`

Initial organization scope: SourceEnergy Group OID only.

Initial actions:
- `work.acknowledge`
- `work.start`
- `evidence.submit`
- `work.exception`
- `work.escalate`

Maximum adapter control level: **C2**.

C3–C6 actions are not autonomous Sidekick execution. They must pause at the governed human authorization boundary.

## 4. Required secret

Production environment variable:

`OEL_SIDEKICK_SHARED_SECRET`

Rules:
1. Generate with a cryptographically secure random source; minimum 32 random bytes.
2. Store only in approved secret stores/environment variables.
3. Never commit the value, test copy, screenshot, or derived reusable credential to GitHub or Drive.
4. Transfer to Sidekick through an approved secure channel.
5. Rotate on suspected disclosure, partner personnel change, environment separation, or scheduled security review.
6. Use different values for development, staging and production.

The deployed gateway is deliberately fail-closed if this secret is absent.

## 5. Signed request envelope

Required fields:
- `client_code`
- `command_id` UUID
- `idempotency_key`
- `nonce`
- `request_timestamp` ISO-8601 UTC
- `correlation_id` UUID
- `trace_id` UUID
- `setc_org_oid`
- `action`
- `resource_type`
- `resource_id` when action requires a resource
- `requested_control_level`
- `actor_external_ref`
- `channel_identity` when channel binding is required
- `payload`
- optional `payload_hash`

Signature header:

`x-oel-signature: <lowercase hex HMAC-SHA256>`

Canonical signing string, newline-delimited in this exact order:

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
sha256(JSON.stringify(payload))
```

The signature is `HMAC-SHA256(secret, canonical_string)` encoded as lowercase hexadecimal.

## 6. Commissioning test matrix

| ID | Test | Expected result |
|---|---|---|
| C001 | Secret absent | 503 CONFIGURATION_ERROR; no command execution |
| C002 | Missing signature | 401 SIGNATURE_REQUIRED |
| C003 | Invalid signature | 401 INVALID_SIGNATURE |
| C004 | Payload changed after signing | 401 PAYLOAD_HASH_MISMATCH or INVALID_SIGNATURE |
| C005 | Unknown client | 403 CLIENT_NOT_ALLOWED |
| C006 | Timestamp outside adapter skew | rejected by adapter registry |
| C007 | Reused nonce | rejected as replay |
| C008 | Reused idempotency key | duplicate receipt; no second execution |
| C009 | Wrong organization OID | rejected by adapter scope |
| C010 | Action not allowlisted | rejected |
| C011 | Requested level > C2 | rejected by adapter ceiling |
| C012 | Unknown actor reference | 403 ACTOR_NOT_RESOLVED |
| C013 | Unverified channel binding | 403 CHANNEL_NOT_VERIFIED |
| C014 | Valid C1 acknowledge | governed command executes once and receipt persists |
| C015 | Valid C2 evidence submit | evidence path executes with provenance and receipt |
| C016 | Escalation requiring C3 | no autonomous material action; human authorization path is created/required |

## 7. Go-live acceptance gate

Production Sidekick traffic remains **NOT COMMISSIONED** until all of the following are evidenced:
- production secret provisioned in Supabase and Sidekick approved environment;
- actor identity mapping established for pilot actors;
- optional channel identities verified where used;
- C001–C016 test evidence captured;
- replay and duplicate-execution protections demonstrated;
- C3 escalation demonstrated to stop at the human authorization boundary;
- logs contain correlation/trace IDs without leaking secrets;
- incident revocation/rotation procedure tested;
- SourceEnergy accountable technical authority signs the commissioning record.

## 8. Release evidence

Store only non-secret evidence:
- test timestamps;
- correlation IDs;
- sanitized request fixtures;
- response status/error codes;
- database receipt IDs;
- relevant commit SHA;
- Edge Function version/hash;
- approver identity and approval reference.

No secret or reusable authentication material belongs in release evidence.
