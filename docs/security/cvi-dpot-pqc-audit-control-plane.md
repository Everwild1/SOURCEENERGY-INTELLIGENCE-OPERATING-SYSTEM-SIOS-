# CVI / DPOT / PQ-CGL Audit Control Plane

Status: CONTROLLED PILOT — NOT PRODUCTION PQC CERTIFICATION  
Protocol: CVI-ONLINE-PRIME  
Assurance profile: HYB-Q3-ECDSA-P256-MLDSA65-V1  
Authoritative runtime label: `PQC_GOVERNED_NOT_YET_PQC_ENFORCED`

## Purpose

This control plane governs evidence-based organizational and individual due diligence, Open Scroll review, Deep-Dive Trace, discernment, and scenario intelligence. It separates internal governance declarations from independently verified facts and separates cryptographic integrity from legal, fiduciary, banking, regulatory, or governmental authority.

The platform may organize and assess lawfully obtained information. It does not authorize covert surveillance, unauthorized device access, private-message interception, real-time location tracking, impersonation, social engineering, credential collection, or government/intelligence-agency representation.

## Supported protected-object classes

| Object type | Subject class | Default handling |
|---|---|---|
| `CVI_OPEN_SCROLL` | System | Restricted, reference-only |
| `DPOT_TRACE_RUN` | System | Restricted, reference-only |
| `ORGANIZATION_DD_REPORT` | Organization | Restricted, retention-limited |
| `INDIVIDUAL_DD_REPORT` | Individual | Highly restricted, lawful-basis and retention required |
| `HIGH_VALUE_AUTHORIZATION` | Transaction | Highly restricted, reference-only |
| `IP_PROVENANCE` | IP | Restricted, reference-only |

Raw due-diligence payloads, bank-account details, credentials, private keys, secret keys, seed material, and unrestricted personal-data fields are prohibited from the PQ-CGL control tables. The database stores governed references, digests, signature envelopes, verification receipts, authorization records, and gate decisions.

## Organizational due diligence

An organizational audit may evaluate, subject to source authority and applicable law:

- legal existence, registration status, jurisdiction, registered officers, and ownership evidence;
- beneficial-ownership declarations and controlling-person evidence;
- sanctions, debarment, politically exposed person, regulatory, and watchlist results from authorized sources;
- licenses, certifications, insurance, litigation, insolvency, and material enforcement history;
- financial-capacity evidence supplied by the organization or an authorized institution;
- cybersecurity, privacy, operational-resilience, vendor, and supply-chain posture;
- related entities, counterparties, conflicts, and transaction relationships;
- adverse-media findings with source provenance, date, identity-resolution confidence, and human review.

The system must distinguish allegation, public record, organization-supplied assertion, third-party corroboration, contradiction, and verified conclusion.

## Individual due diligence

An individual audit requires a documented lawful basis or consent, accountable authority reference, defined purpose, minimum-necessary attestation, and retention deadline before registration.

Permitted assessment domains may include:

- identity resolution and KYC evidence supplied through authorized channels;
- sanctions, politically exposed person, debarment, professional-license, and credential checks;
- directorships, beneficial-ownership roles, conflicts of interest, and authorized employment history;
- litigation, regulatory, fraud, or adverse-media findings from lawful sources;
- source-provenance, identity-match confidence, contradiction review, and human adjudication.

The audit control plane does not infer a person's live location, access private accounts, obtain non-public communications, or treat spiritual, prophetic, behavioral, or model-generated impressions as verified personal facts.

## Evidence taxonomy

Every material conclusion must be classified as one of:

- `OBSERVED` — directly present in an authorized source;
- `CORROBORATED` — independently supported by more than one authorized source;
- `VERIFIED` — applicable verification requirements and accountable review have passed;
- `CONFLICTED` — reliable sources materially disagree;
- `INFERENCE` — reasoned conclusion that is not directly established;
- `SCENARIO_NOT_FACT` — forecast, risk, opportunity, timing window, or alternative path;
- `UNOBSERVED` — required evidence has not been obtained.

A forecast, prophecy record, discernment, confidence score, or automated model output cannot promote an assertion to `VERIFIED` without the controlling evidence gate.

## Hybrid cryptographic evidence flow

1. The canonical report remains in an approved governed repository or case system.
2. The control plane registers an opaque content reference and a SHA-384 digest.
3. An approved external signer produces the classical signature component.
4. An approved external post-quantum signer produces the ML-DSA-65 component.
5. Verification receipts identify the engine, registered public-key reference, fingerprint, algorithm, time, and result.
6. The signature components are bound to the same object type, identifier, version, digest, and policy.
7. Accountable human authorization is recorded as an append-only event.
8. `pqc.request_protected_object_transition()` evaluates the evidence and records a PASS or BLOCK decision before any state change.

PostgreSQL orchestrates evidence and enforces gates. It does not generate, store, or independently validate private ML-DSA or ECDSA key material.

## State model

`DRAFT -> HASHED -> SIGNING -> PILOT_VERIFIED -> RELEASE_READY -> RETIRED`

A transition to `PILOT_VERIFIED` requires:

- a valid registered classical signature component;
- a valid registered ML-DSA-65 component;
- external verification receipts;
- active key references;
- accountable pilot authorization.

A transition to `RELEASE_READY` additionally requires the hybrid profile to be production-active. The current profile is `pilot`, so production release remains blocked by design.

## Current posture

The control plane and fail-closed gates are installed. The initial CV-ENTRY-002 Open Scroll is registered as `HASHED`. No operational PQC keys or valid PQC signature envelopes are registered, and no object is `PILOT_VERIFIED` or `RELEASE_READY`.

Therefore, the only defensible interface statement is:

> PQC governance active; hybrid evidence pilot commissioned; end-to-end post-quantum protection not yet established.

## Remaining commissioning gates

- select and approve an external KMS/HSM or signing provider with evidenced ML-DSA-65 support;
- conduct a controlled key ceremony without copying private material into SIOS;
- register key references and public fingerprints;
- implement deterministic payload canonicalization and detached signing;
- verify classical and ML-DSA signatures through an independent engine;
- complete positive-path interoperability, downgrade, revocation, recovery, and replay tests;
- obtain accountable approval before changing the hybrid profile from `pilot` to `active`;
- maintain periodic vendor, algorithm, certificate, dependency, and incident-readiness reviews.
