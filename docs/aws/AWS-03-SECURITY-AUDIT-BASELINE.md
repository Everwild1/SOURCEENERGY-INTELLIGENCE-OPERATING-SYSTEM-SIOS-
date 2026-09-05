# AWS-03 — Security & Audit Baseline

Status: deployment-ready infrastructure-as-code; not yet applied to AWS.

## Purpose

AWS-03 establishes the SourceEnergy account-level management-event audit baseline before SIOS runtime infrastructure is introduced.

## Current-state findings

- Connected account currently resolves to root identity; routine operations must migrate away from root.
- Root MFA is active; credential report showed root access keys inactive.
- GitHub OIDC provider exists and `GitHubActions-SIOS-Verify` is scoped to the SIOS `main` branch.
- No CloudTrail trail currently exists.
- No GuardDuty detector currently exists in the 17 enabled standard regions inspected.
- Existing Phase-1 S3 governance buckets are public-blocked, BucketOwnerEnforced, versioned, and TLS-only.
- Audit Archive, Disaster Recovery, and Evidence Vault use separate customer-managed KMS keys and governance-mode Object Lock.
- Existing Phase-1 KMS key policies are account-root/IAM-policy delegated and do not contain an explicit CloudTrail service statement; AWS-03 therefore creates a dedicated CloudTrail CMK rather than altering those existing keys.

## AWS-03 architecture

`AWS management events (all regions + global services) -> CloudTrail -> dedicated CMK-encrypted Object-Locked S3 audit bucket + CMK-encrypted CloudWatch Logs`

The dedicated CloudTrail bucket sends S3 server-access logs to the existing Phase-1 access-log bucket. Existing Audit Archive, Evidence Vault, and Disaster Recovery buckets are not replaced or repurposed.

## Governance decisions

1. Management events only in the initial baseline.
2. CloudTrail data events are deferred because they can be high-volume and incur additional charges.
3. CloudTrail Insights is deferred because it is a premium feature and should be separately approved.
4. Multi-region and global-service coverage are mandatory.
5. Log-file validation is mandatory.
6. S3 and CloudWatch audit data use a dedicated customer-managed KMS key.
7. CloudTrail S3 objects use governance-mode Object Lock and versioning.
8. Stateful audit resources use Retain deletion/update-replacement policies.
9. Existing SourceEnergy Phase-1 governance buckets remain authoritative for their current functions.

## Deployment gate

Before deployment:

- validate CloudFormation syntax/schema;
- run security/compliance checks;
- create and inspect a CloudFormation change set;
- confirm the deployment identity is not root and has only the permissions required for the stack;
- confirm the existing access-log bucket remains available in `us-west-2`;
- do not enable data events or Insights without separate approval.

After deployment verify:

- trail `IsLogging = true`;
- `IsMultiRegionTrail = true`;
- global service events enabled;
- log-file validation enabled;
- management Read + Write events enabled;
- CloudWatch log group exists with explicit retention;
- S3 bucket has Block Public Access, KMS encryption, versioning, Object Lock, TLS-only policy;
- CloudTrail log delivery reaches both S3 and CloudWatch;
- test API events are visible from at least two standard regions after propagation.

## Deferred controls

AWS-04 should address operational/federated administration and GitHub deployment roles. GuardDuty/Security Hub regional activation and cross-region disaster-recovery replication should be separately costed and governed rather than silently bundled into AWS-03.
