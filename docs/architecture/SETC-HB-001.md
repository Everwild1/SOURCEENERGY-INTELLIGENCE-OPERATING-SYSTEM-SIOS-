# SETC-HB-001 — HeartBeat Biometric Identity Integration

Status: implementation crosswalk

Authoritative architecture source: SourceEnergy Ecosystem / Product & Platform Engineering / 02 System Architecture / SETC-HB-001.

## Governing boundary

HeartBeat authenticates a human. Cryptography authorizes a transaction. SETC governance determines substantive authority.

HeartBeat must not assign roles, create delegations, approve capital, release funds, promote canonical knowledge, or mutate another domain's authoritative state.

## Capability namespaces

- `SETC-HB-ID`: cardiac identity.
- `SETC-HB-LIVE`: proof-of-life / presentation-attack resistance.
- `SETC-HB-CONT`: physiological continuity re-evaluation.
- `SETC-HB-AUTH`: binding of a biometric assertion to the current authorization context.

## Security-object separation

The following are distinct objects and must never be conflated:

1. biometric signal;
2. protected biometric template;
3. cryptographic private key;
4. blockchain identity;
5. biometric authentication assertion;
6. infrastructure/system heartbeat observation.

A biometric decision may permit a policy-governed hardware-backed signing operation. The heartbeat is not a deterministic private key.

## NASA / third-party IP boundary

The legacy Source ID / SCV-16 cardiac feature family is treated as an engineering baseline subject to the separate IP Blockchain Matrix and applicable NASA/third-party patent, licensing, chain-of-title, prior-art, and freedom-to-operate review. This implementation document makes no ownership, licensing, patentability, or freedom-to-operate conclusion.

## Privacy boundary

Raw ECG/PPG signals and reusable biometric templates must not be written to public or immutable ledgers. Audit records should contain bounded authentication/authorization attestations and references only.

## Identifier boundary

- `cardiac_credential_id`: opaque enrollment credential reference.
- `template_id`: protected template reference.
- `assertion_id`: authentication assertion reference.
- `correlation_id`: event/audit linkage.
- `system_heartbeat_observation_id`: infrastructure telemetry only; never HBID.

## Integration flow

Human → cardiac sensor → signal quality / sensor integrity → feature extraction → liveness → match → bounded assertion → IAM integration → policy decision → hardware-backed signing → governed action → AuditLedger.

## Production gate

No HeartBeat capability is production-ready solely from laboratory accuracy. Release requires architecture, security, privacy, data-governance, biometric-performance, resilience, fallback, incident-response, and SETC-076 approval evidence.
