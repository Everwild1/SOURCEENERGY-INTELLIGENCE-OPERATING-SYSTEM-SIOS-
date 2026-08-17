from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations.judgment_execution import (
    ExecutionOrder,
    ExecutionState,
    ExecutionVerification,
    InstitutionalJudgment,
    JudgmentExecutionRecord,
    JudgmentSatisfactionRecord,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def now() -> datetime:
    return datetime.now(timezone.utc)


def test_judgment_requires_independent_issuer() -> None:
    with pytest.raises(ValueError):
        InstitutionalJudgment(
            judgment_id=sid("judgment-1"),
            determination_id=sid("determination-1"),
            subject_organization_id=sid("org-1"),
            issuing_organization_id=sid("org-1"),
            judgment_reference="judgment-ref",
            rationale="Reasoned judgment",
            issued_at=now(),
            evidence_references=("evidence-1",),
        )


def test_execution_order_separates_ordering_and_responsible_organizations() -> None:
    with pytest.raises(ValueError):
        ExecutionOrder(
            order_id=sid("order-1"),
            judgment_id=sid("judgment-1"),
            ordering_organization_id=sid("org-2"),
            responsible_organization_id=sid("org-2"),
            action="Execute remedy",
            authority_reference="authority-1",
            evidence_reference="evidence-1",
        )


def test_completed_execution_requires_evidence() -> None:
    with pytest.raises(ValueError):
        JudgmentExecutionRecord(
            execution_id=sid("execution-1"),
            order_id=sid("order-1"),
            executing_organization_id=sid("org-3"),
            state=ExecutionState.COMPLETED,
            action="Completed remedy",
            recorded_at=now(),
        )


def test_execution_verification_requires_independent_verifier() -> None:
    with pytest.raises(ValueError):
        ExecutionVerification(
            verification_id=sid("verification-1"),
            execution_id=sid("execution-1"),
            executing_organization_id=sid("org-3"),
            verifier_organization_id=sid("org-3"),
            verified=True,
            evidence_references=("evidence-1",),
        )


def test_satisfaction_requires_independent_confirmation() -> None:
    with pytest.raises(ValueError):
        JudgmentSatisfactionRecord(
            satisfaction_id=sid("satisfaction-1"),
            judgment_id=sid("judgment-1"),
            subject_organization_id=sid("org-1"),
            confirming_organization_id=sid("org-1"),
            satisfied_at=now(),
            evidence_references=("evidence-1",),
        )
