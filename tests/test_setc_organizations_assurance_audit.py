from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    AssuranceEngagement,
    AssuranceOpinion,
    AssuranceOpinionRecord,
    AuditEvidenceRecord,
    AuditFinding,
    AuditFindingSeverity,
    RemediationVerification,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def now() -> datetime:
    return datetime.now(timezone.utc)


def test_assurance_engagement_requires_independent_auditor() -> None:
    with pytest.raises(ValueError):
        AssuranceEngagement(
            engagement_id=sid("engagement-1"),
            subject_organization_id=sid("org-1"),
            auditor_organization_id=sid("org-1"),
            engagement_reference="audit-2026",
            scope="institutional controls",
        )


def test_audit_evidence_requires_source_and_reference() -> None:
    with pytest.raises(ValueError):
        AuditEvidenceRecord(
            evidence_id=sid("evidence-1"),
            engagement_id=sid("engagement-1"),
            collected_by_organization_id=sid("org-2"),
            source_reference="",
            evidence_reference="evidence://1",
            collected_at=now(),
        )


def test_audit_finding_requires_evidence() -> None:
    with pytest.raises(ValueError):
        AuditFinding(
            finding_id=sid("finding-1"),
            engagement_id=sid("engagement-1"),
            subject_organization_id=sid("org-1"),
            finding="Material control deficiency",
            severity=AuditFindingSeverity.HIGH,
        )


def test_verified_remediation_requires_independent_verifier() -> None:
    with pytest.raises(ValueError):
        RemediationVerification(
            verification_id=sid("verification-1"),
            remediation_id=sid("remediation-1"),
            subject_organization_id=sid("org-1"),
            verifier_organization_id=sid("org-1"),
            verified=True,
            evidence_references=("evidence://2",),
        )


def test_verified_remediation_requires_evidence() -> None:
    with pytest.raises(ValueError):
        RemediationVerification(
            verification_id=sid("verification-1"),
            remediation_id=sid("remediation-1"),
            subject_organization_id=sid("org-1"),
            verifier_organization_id=sid("org-2"),
            verified=True,
        )


def test_assurance_opinion_requires_evidence() -> None:
    with pytest.raises(ValueError):
        AssuranceOpinionRecord(
            opinion_id=sid("opinion-1"),
            engagement_id=sid("engagement-1"),
            issuing_organization_id=sid("org-2"),
            opinion=AssuranceOpinion.UNMODIFIED,
            rationale="Controls are fairly presented",
            issued_at=now(),
        )
