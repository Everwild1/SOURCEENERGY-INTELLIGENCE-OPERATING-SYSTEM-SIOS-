from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    ComplianceAssessmentRecord,
    ComplianceMandate,
    ComplianceRemediationRecord,
    ComplianceSupervisionState,
    ComplianceVerification,
    SupervisoryActionState,
    SupervisoryDirective,
    SupervisoryEscalation,
    SupervisoryFinding,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def now() -> datetime:
    return datetime.now(timezone.utc)


def test_compliance_mandate_requires_independent_supervisor() -> None:
    with pytest.raises(ValueError):
        ComplianceMandate(
            mandate_id=sid("mandate-1"),
            subject_organization_id=sid("org-1"),
            supervising_organization_id=sid("org-1"),
            obligation_reference="obligation-1",
            scope="regulated activity",
            authority_reference="authority-1",
        )


def test_material_compliance_assessment_requires_evidence() -> None:
    with pytest.raises(ValueError):
        ComplianceAssessmentRecord(
            assessment_id=sid("assessment-1"),
            mandate_id=sid("mandate-1"),
            subject_organization_id=sid("org-1"),
            assessing_organization_id=sid("org-2"),
            state=ComplianceSupervisionState.DEFICIENT,
            rationale="control deficiency",
            assessed_at=now(),
        )


def test_supervisory_finding_requires_evidence() -> None:
    with pytest.raises(ValueError):
        SupervisoryFinding(
            finding_id=sid("finding-1"),
            mandate_id=sid("mandate-1"),
            subject_organization_id=sid("org-1"),
            supervising_organization_id=sid("org-2"),
            finding="material deficiency",
        )


def test_supervisory_directive_separates_issuer_and_responsible_org() -> None:
    with pytest.raises(ValueError):
        SupervisoryDirective(
            directive_id=sid("directive-1"),
            finding_id=sid("finding-1"),
            issuing_organization_id=sid("org-2"),
            responsible_organization_id=sid("org-2"),
            action="remediate control",
            authority_reference="authority-1",
            evidence_reference="evidence-1",
        )


def test_completed_remediation_requires_evidence() -> None:
    with pytest.raises(ValueError):
        ComplianceRemediationRecord(
            remediation_id=sid("remediation-1"),
            directive_id=sid("directive-1"),
            responsible_organization_id=sid("org-1"),
            action="completed remediation",
            state=SupervisoryActionState.COMPLETED,
            recorded_at=now(),
        )


def test_compliance_verification_requires_independent_verifier() -> None:
    with pytest.raises(ValueError):
        ComplianceVerification(
            verification_id=sid("verification-1"),
            remediation_id=sid("remediation-1"),
            responsible_organization_id=sid("org-1"),
            verifying_organization_id=sid("org-1"),
            verified=True,
            evidence_references=("evidence-1",),
        )


def test_supervisory_escalation_requires_distinct_organizations() -> None:
    with pytest.raises(ValueError):
        SupervisoryEscalation(
            escalation_id=sid("escalation-1"),
            mandate_id=sid("mandate-1"),
            from_organization_id=sid("org-2"),
            to_organization_id=sid("org-2"),
            reason="persistent deficiency",
            authority_reference="authority-1",
            evidence_reference="evidence-1",
        )
