# SE1-08A — HeartBeatID & Biometric Identity Assurance

Status: Draft / gated integration
Architecture authority: SETC-HB-001 and DHN HeartBeatID domain architecture

## Purpose

Integrate HeartBeatID into SourceEnergy One as a high-assurance human identity and presence factor without allowing biometric data to become a definition of the person's purpose, health, authority or institutional status.

## Canonical flow

Person -> approved HeartBeatID capture/verification service -> bounded verification assertion -> SourceEnergy One Access Context -> policy evaluation -> SourceCube -> human authorization where required -> SIOS/SETC execution.

## Separation of concerns

HeartBeatID answers: is the authorized human associated with this verification event/session/action with the required assurance?

Purpose Discovery / Codex 24 answers: what candidate Mission, Vision, Purpose and impact interpretation is supported by the participant's testimony?

SETC Genesis answers: what approved, versioned starting-state/provenance package has been authorized?

These are separate trust domains and may not silently substitute for one another.

## SourceEnergy One data boundary

SourceEnergy One stores only opaque enrollment references and bounded verification assertions. It must not store raw ECG/PPG/PCG/LDV/radar signals, reusable cardiac templates, medical interpretations or diagnostic outputs in its ordinary identity, Genesis or orchestration tables.

A verification assertion may include: subject reference, challenge ID, verified/failed/indeterminate state, liveness state, assurance level, sensor/device attestation reference, algorithm version, policy version, consent receipt, assertion digest, evidence references, issuance/expiry and revocation state.

## Authentication uses

Permitted integration uses include enrollment binding, login/MFA where law/policy permit, step-up authentication, proof-of-life/presence for governed transactions, session re-verification, and authorization-gate evidence.

A successful HeartBeatID assertion is an authentication factor; it is not by itself authorization to execute a consequential action.

## Genesis boundary

Genesis may reference the credential/assertion provenance and digest when needed. Genesis must not contain raw physiological signals or reusable biometric templates. Authentication and longitudinal physiological observation are separate processing purposes and require separate consent/policy treatment.

## Licensing/IP gate

The SETC-HB-001 working record identifies the NASA HeartBeatID 16x12/192-parameter architecture as legacy NASA platform IP / licensing dependency rather than new SourceEnergy core IP. Therefore the SourceEnergy One `heartbeat-id` adapter remains disabled for production integration until licensing/field-of-use and implementation rights are confirmed.

SourceEnergy-specific improvement work may proceed around governed assertions, policy-bound non-exportable signing, sensor-attested liveness, continuity-triggered authorization re-evaluation and privacy-preserving assertion mechanisms, subject to prior-art, licensing and counsel review.

## Security requirements

- fail closed on expired/revoked/indeterminate assertions;
- challenge/freshness binding and replay resistance;
- sensor/device attestation where required by assurance policy;
- no biometric-derived private keys;
- cryptographic signing keys remain separate and non-exportable where hardware-backed signing is used;
- data minimization and purpose-specific consent;
- no diagnostic inference in the identity pathway;
- correlation/audit ID on step-up and consequential authorization flows;
- revocation and credential re-enrollment pathway;
- accessible fallback authentication governed by policy.

## Backend objects

`sourceenergy_one.heartbeat_enrollment_refs`
`sourceenergy_one.heartbeat_verification_assertions`
`sourceenergy_one.access_contexts.heartbeat_assertion_id`
`sourceenergy_one.access_contexts.authentication_factors`
`sourceenergy_one.domain_adapter_registry['heartbeat-id']`

The adapter is initially disabled and marked `licensing_gate_required`.
