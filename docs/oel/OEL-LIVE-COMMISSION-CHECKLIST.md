# OEL-LIVE-COMMISSION-001 — Sidekick Gateway Live Commissioning Checklist

**Status:** PENDING CREDENTIAL + LIVE EVIDENCE  
**Authority:** SourceEnergy Group  
**Boundary:** SourceEnergy × Sidekick Organizational Execution Layer  
**Gateway:** `oel-sidekick-command-gateway`  

## Preconditions

- [x] GitHub deterministic contract CI green.
- [x] C001–C016 vector specification complete.
- [x] Sidekick adapter registered with SourceEnergy Group-only organization scope.
- [x] Adapter autonomous ceiling fixed at C2.
- [x] C3–C6 material execution requires accountable human authorization.
- [x] Trusted database dispatcher `oel.execute_adapter_command(uuid)` deployed with explicit actor context.
- [x] Edge gateway V2 routes accepted commands only through trusted dispatcher.
- [ ] Sidekick production/pre-production signing credential received through approved secure channel.
- [ ] `OEL_SIDEKICK_SHARED_SECRET` provisioned in Edge Function environment without repository exposure.
- [ ] Commissioning actor mapped to active SourceEnergy One identity.
- [ ] Commissioning work item prepared in a reversible/non-production test context.
- [ ] Optional channel identity verified when channel binding is tested.

## Credential Controls

1. Never paste the production credential into GitHub, Drive, PR comments, CI logs, test evidence, chat transcripts or source files.
2. Minimum 32 random bytes for the interim HMAC secret.
3. Environment-specific credential; do not reuse a production credential in local/CI fixtures.
4. Record only secret identifier/version, provisioning timestamp, custodian and rotation status.
5. Rotate immediately if any disclosure is suspected.
6. Prefer Sidekick-supported asymmetric signing for production if available; HMAC-SHA256 remains the current interim SourceEnergy contract until Sidekick confirms its production signing protocol.

## Live Acceptance Matrix

| ID | Control | Required Evidence | Gate |
|---|---|---|---|
| C001 | Secret absent | 503 fail-closed response from controlled pre-provision test | PASS required |
| C002 | Missing signature | 401 `SIGNATURE_REQUIRED` | PASS required |
| C003 | Invalid signature | 401 `INVALID_SIGNATURE` | PASS required |
| C004 | Payload tamper | payload hash/signature rejection | PASS required |
| C005 | Unknown client | 403 rejection | PASS required |
| C006 | Stale timestamp | clock-skew rejection | PASS required |
| C007 | Nonce replay | duplicate/replay rejection | PASS required |
| C008 | Idempotency replay | duplicate receipt; no second execution | PASS required |
| C009 | Wrong organization | rejection | PASS required |
| C010 | Action outside allowlist | rejection | PASS required |
| C011 | Requested C3 autonomous level | rejection at adapter ceiling | PASS required |
| C012 | Unknown actor | rejection | PASS required |
| C013 | Unverified channel | rejection when channel binding supplied | PASS required |
| C014 | Valid C1 acknowledge | one state transition + event + duplicate-safe replay | PASS required |
| C015 | Valid C2 evidence | evidence record + provenance event + receipt | PASS required |
| C016 | Escalation to C3 | `REQUIRES_HUMAN_APPROVAL` + canonical authorization request; no material autonomous execution | PASS required |

## Execution Harness

Use `tests/oel/live-sidekick-commission.mjs` only from an approved commissioning environment. The harness reads the credential from `OEL_SIDEKICK_SHARED_SECRET`; it never requires the credential in command-line arguments or source code.

Required environment variables:

- `OEL_GATEWAY_URL`
- `OEL_SIDEKICK_SHARED_SECRET`
- `OEL_ACTOR_EXTERNAL_REF`
- `OEL_WORK_ITEM_ID`

Optional:

- `OEL_CHANNEL_IDENTITY`
- `OEL_SETC_ORG_OID`
- `OEL_EVIDENCE_FILE`
- `OEL_RUN_MUTATING_TESTS=true` only after the commissioning work item is approved for mutation.

## Evidence Package

The commissioning evidence package must contain no secret values. Preserve:

- Edge Function version and SHA-256.
- Git commit SHA and PR number.
- commissioning timestamp and accountable operator.
- adapter client code and organization scope.
- actor reference/identity record ID, but no authentication token.
- command/correlation/trace IDs.
- HTTP status and sanitized response for each vector.
- adapter command ID, receipt ID, OEL event ID(s), evidence ID where applicable.
- canonical SourceEnergy One authorization request ID for C016.
- database verification that C014 executed once, C015 created provenance, and C016 did not autonomously execute the C3 action.
- explicit PASS/FAIL for every C001–C016 vector.

## Go / No-Go

**GO** requires all C001–C016 controls PASS, no secret exposure, durable evidence reconciliation, C2 ceiling intact, C3+ human gate intact, and accountable SourceEnergy commissioning approval.

Any failed security/governance vector is **NO-GO**. Do not merge PR #278 and do not describe the gateway as production commissioned until the failed gate is remediated and retested.
