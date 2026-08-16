from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    RemediationCompletionRecord,
    RemediationObligation,
    RemediationState,
    RemediationValidation,
    ResolutionMilestone,
    ResolutionPlan,
    ResolutionRecord,
    ResolutionState,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_completed_remediation_requires_evidence():
    with pytest.raises(ValueError, match="material remediation state requires evidence"):
        RemediationObligation(
            sid("rem-1"), "finding:1", sid("org-subject"), sid("org-owner"),
            "Correct the control deficiency", "authority:1", RemediationState.COMPLETED,
        )


def test_responsible_organization_cannot_self_approve_resolution_plan():
    with pytest.raises(ValueError, match="cannot self-approve"):
        ResolutionPlan(
            sid("plan-1"), sid("rem-1"), sid("org-owner"), "plan:1", "Resolve deficiency",
            approved_by_organization_id=sid("org-owner"),
        )


def test_completed_milestone_requires_evidence():
    with pytest.raises(ValueError, match="completed milestone requires evidence"):
        ResolutionMilestone(
            sid("mile-1"), sid("plan-1"), "Deploy corrective control",
            completed_at=datetime.now(timezone.utc),
        )


def test_completion_requires_evidence():
    with pytest.raises(ValueError, match="completion requires evidence"):
        RemediationCompletionRecord(
            sid("complete-1"), sid("rem-1"), sid("org-owner"),
            datetime.now(timezone.utc), "Control deployed",
        )


def test_validation_requires_independent_validator():
    with pytest.raises(ValueError, match="independent validator"):
        RemediationValidation(
            sid("val-1"), sid("rem-1"), sid("org-owner"), sid("org-owner"), True,
            ("evidence:1",),
        )


def test_validated_remediation_requires_evidence():
    with pytest.raises(ValueError, match="validated remediation requires evidence"):
        RemediationValidation(
            sid("val-1"), sid("rem-1"), sid("org-owner"), sid("org-validator"), True,
        )


def test_resolved_record_requires_evidence():
    with pytest.raises(ValueError, match="resolved or closed resolution requires evidence"):
        ResolutionRecord(
            sid("resolution-1"), sid("rem-1"), sid("org-subject"), sid("org-resolver"),
            ResolutionState.RESOLVED, "All corrective actions completed",
        )
