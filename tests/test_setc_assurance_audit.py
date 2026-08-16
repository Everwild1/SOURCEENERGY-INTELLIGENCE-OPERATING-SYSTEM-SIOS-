from datetime import UTC, datetime

import pytest

from setc.core import SETCIdentifier
from setc.organizations.assurance_audit import (
    AssuranceEngagement,
    AssuranceOpinion,
    AssuranceOpinionRecord,
    AuditFinding,
    AuditFindingSeverity,
    RemediationVerification,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_assurance_engagement_requires_independent_auditor() -> None:
    with pytest.raises(ValueError, match="independent auditor"):
        AssuranceEngagement(
            engagement_id=sid("ENG-1"),
            subject_organization_id=sid("ORG-1"),
            auditor_organization_id=sid("ORG-1"),
            engagement_reference="AUD-2026-001",
            scope="Institutional controls",
        )


def test_audit_finding_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        AuditFinding(
            finding_id=sid("FIND-1"),
            engagement_id=sid("ENG-1"),
            subject_organization_id=sid("ORG-1"),
            finding="Control was not operating effectively",
            severity=AuditFindingSeverity.HIGH,
        )


def test_verified_remediation_requires_independent_verifier_and_evidence() -> None:
    with pytest.raises(ValueError, match="independent verifier"):
        RemediationVerification(
            verification_id=sid("VER-1"),
            remediation_id=sid("REM-1"),
            subject_organization_id=sid("ORG-1"),
            verifier_organization_id=sid("ORG-1"),
            verified=True,
            evidence_references=("evidence://verification",),
        )

    with pytest.raises(ValueError, match="requires evidence"):
        RemediationVerification(
            verification_id=sid("VER-2"),
            remediation_id=sid("REM-1"),
            subject_organization_id=sid("ORG-1"),
            verifier_organization_id=sid("ORG-2"),
            verified=True,
        )


def test_assurance_opinion_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        AssuranceOpinionRecord(
            opinion_id=sid("OP-1"),
            engagement_id=sid("ENG-1"),
            issuing_organization_id=sid("ORG-2"),
            opinion=AssuranceOpinion.UNMODIFIED,
            rationale="Controls are fairly represented",
            issued_at=datetime.now(UTC),
        )
