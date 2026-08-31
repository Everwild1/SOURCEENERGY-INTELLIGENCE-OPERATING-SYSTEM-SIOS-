# PQC Provider Commissioning and Key Ceremony Runbook

Status: CONTROLLED PLANNING BASELINE — HUMAN APPROVAL REQUIRED  
Primary pilot candidate: AWS KMS  
Interoperability benchmark: Google Cloud KMS  
Target signature profile: `HYB-Q3-ECDSA-P256-MLDSA65-V1`  
Authoritative posture: `PQC_GOVERNED_NOT_YET_PQC_ENFORCED`

## Purpose

This runbook governs the transition from a database-enforced post-quantum policy model to a bounded, evidence-backed cryptographic pilot. It does not authorize cloud-account creation, spending, key generation, production activation, intelligence-agency representation, external banking connectivity, or the storage of private key material.

The commissioning control plane records provider evidence, selection recommendations, accountable approval decisions, key-ceremony plans, public key references and fingerprints, interoperability results, and promotion gates. Private keys remain inside the selected managed cryptographic boundary.

## Provider decision

### Preferred non-production pilot candidate: AWS KMS

AWS KMS is recommended for the first bounded ML-DSA-65 pilot because official AWS documentation describes:

- FIPS 204 ML-DSA key specifications `ML_DSA_44`, `ML_DSA_65`, and `ML_DSA_87`;
- the `ML_DSA_SHAKE_256` signing algorithm;
- `RAW` and `EXTERNAL_MU` message modes;
- managed signing and verification through established KMS APIs;
- protection of ML-DSA keys and operations in AWS-managed hardware security modules.

This is a capability recommendation only. SourceEnergy has not yet evidenced the selected AWS account, region, IAM model, audit configuration, billing boundary, key policy, key material, or operational test result.

Primary evidence references:

- https://docs.aws.amazon.com/kms/latest/developerguide/mldsa.html
- https://docs.aws.amazon.com/kms/latest/APIReference/API_Sign.html
- https://aws.amazon.com/about-aws/whats-new/2025/06/aws-kms-post-quantum-ml-dsa-digital-signatures/

### Interoperability benchmark: Google Cloud KMS

Google Cloud KMS is retained as an independent benchmark because official Google Cloud materials identify generally available post-quantum signing algorithms, including ML-DSA parameter sets and SLH-DSA. Its role in this phase is comparative verification and interoperability planning, not automatic production selection.

Primary evidence references:

- https://docs.cloud.google.com/kms/docs/release-notes
- https://cloud.google.com/blog/products/identity-security/future-proofing-data-integrity-quantum-safe-digital-signatures-in-cloud-kms

## Commissioning states

The control plane uses the following provider states:

1. `CANDIDATE` — capability evidence has been identified but no preference or approval exists.
2. `PREFERRED_FOR_PILOT` — an evidence-backed recommendation exists; no authority to spend or create keys exists.
3. `APPROVED_FOR_PILOT` — accountable authorization permits only the bounded non-production pilot.
4. `APPROVED_FOR_PRODUCTION` — independent validation and accountable production authorization have passed.
5. `SUSPENDED` or `REJECTED` — the provider may not be used for new commissioning activity.

A recommendation is never interpreted as approval.

## Required human decision package

Before the provider may advance to `APPROVED_FOR_PILOT`, the authorization package must identify:

- accountable approving authority;
- cloud-account owner and administrative custodian;
- selected region and documented service availability;
- maximum pilot spend and billing-alert boundary;
- IAM roles for key administration, signing, verification, audit, and incident response;
- separation of duties between key administrators, signers, auditors, and approvers;
- log destination, retention period, and evidence export process;
- key alias and naming convention;
- deletion, disablement, revocation, recovery, and incident-response procedure;
- two independent key-ceremony approvers;
- permitted pilot objects and explicit production prohibition.

## Planned ceremony

Ceremony code: `AWS-KMS-MLDSA65-PILOT-001`

The ceremony must remain `PLANNED` until the provider approval decision, account authority, cost boundary, region, IAM design, and audit configuration are documented.

The ceremony sequence is:

1. Verify the provider approval record and evidence cutoff.
2. Confirm the AWS account and selected region through an authorized administrator.
3. Confirm budget authorization and activate billing alerts.
4. Establish least-privilege IAM roles and separation of duties.
5. Enable and verify attributable audit logging.
6. Create one non-production ML-DSA-65 signing key through the managed provider.
7. Record only the provider key reference, public key fingerprint, algorithm, region, status, and evidence references in SIOS.
8. Never export or copy private key material into GitHub, Supabase, Drive, chat, tickets, documents, environment variables, or ordinary application storage.
9. Obtain two independent ceremony authorizations.
10. Execute the required interoperability tests.
11. Register the key as active for `PILOT` scope only after the ceremony and approval gates pass.

## Required test suite

The pilot cannot advance until all required tests pass with attributable evidence:

- `AWS-MLDSA65-RAW-SIGN-VERIFY` — normal sign/verify for a bounded RAW payload;
- `AWS-MLDSA65-EXTERNAL-MU` — external-mu path for larger canonical payloads;
- `AWS-MLDSA65-OFFLINE-VERIFY` — independent verification using the exported public key;
- `AWS-MLDSA65-TAMPER-REJECT` — modified payload rejection;
- `AWS-MLDSA65-WRONG-KEY-REJECT` — wrong-key rejection;
- `AWS-MLDSA65-REVOKE-DISABLE` — disablement and revocation behavior;
- `AWS-MLDSA65-AUDIT-RECEIPT` — attributable audit evidence for key lifecycle and cryptographic operations.

The optional `AWS-GCP-MLDSA65-CROSS-VERIFY` test provides an independent cross-provider comparison and does not replace offline standards-conformant verification.

## Promotion gates

### Pilot key activation

An ML-DSA key cannot become `active` unless:

- the provider is `APPROVED_FOR_PILOT` or `APPROVED_FOR_PRODUCTION`;
- an append-only approved provider decision exists;
- the matching ceremony is `COMPLETE`;
- provider reference, fingerprint, evidence reference, algorithm, environment, and ceremony record match;
- the required number of independent ceremony approvals exists;
- no private or secret key material is present in registry metadata.

### Production profile activation

The hybrid profile cannot become `active` unless:

- the provider is `APPROVED_FOR_PRODUCTION`;
- approved production-scope classical and ML-DSA keys are active;
- their matching ceremonies are complete;
- every required interoperability test has passed;
- production release is explicitly enabled through governed metadata;
- accountable production authorization is recorded.

## Current baseline

At commissioning-baseline creation:

- assessed providers: 2;
- preferred pilot providers: 1;
- approved pilot providers: 0;
- approved production providers: 0;
- planned ceremonies: 1;
- completed ceremonies: 0;
- required tests pending: 7;
- active PQC keys: 0;
- valid PQC signature envelopes: 0;
- end-to-end PQC evidence established: false.

The system must continue to display `PROVIDER_PREFERRED_AWAITING_HUMAN_APPROVAL` for provider commissioning and `PQC_GOVERNED_NOT_YET_PQC_ENFORCED` for operational quantum posture until the controlling evidence changes.

## Prohibited interpretations

This commissioning baseline must not be represented as:

- a completed AWS or Google Cloud deployment;
- cloud spend authorization;
- a completed key ceremony;
- an active ML-DSA key;
- a valid post-quantum signature;
- production PQC certification;
- QKD or quantum-network deployment;
- intelligence-agency accreditation or affiliation;
- proof of external banking or settlement connectivity.
