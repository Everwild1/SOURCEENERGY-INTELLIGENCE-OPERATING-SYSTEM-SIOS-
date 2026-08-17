from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    AdjudicativeDetermination,
    AdjudicativeFinding,
    AdjudicativeProceeding,
    AdjudicativeRemedy,
    AdjudicationOutcome,
    ProceedingNotice,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def now() -> datetime:
    return datetime.now(timezone.utc)


def test_adjudication_requires_independent_adjudicator() -> None:
    with pytest.raises(ValueError):
        AdjudicativeProceeding(
            proceeding_id=sid("proceeding-1"),
            subject_organization_id=sid("org-1"),
            adjudicating_organization_id=sid("org-1"),
            matter_reference="matter-1",
            jurisdiction_reference="jurisdiction-1",
        )


def test_notice_requires_service_evidence() -> None:
    with pytest.raises(ValueError):
        ProceedingNotice(
            notice_id=sid("notice-1"),
            proceeding_id=sid("proceeding-1"),
            recipient_organization_id=sid("org-1"),
            notice_reference="notice-doc",
            served_at=now(),
            service_evidence_reference="",
        )


def test_finding_requires_evidence() -> None:
    with pytest.raises(ValueError):
        AdjudicativeFinding(
            finding_id=sid("finding-1"),
            proceeding_id=sid("proceeding-1"),
            finding="Material finding",
        )


def test_determination_requires_evidence() -> None:
    with pytest.raises(ValueError):
        AdjudicativeDetermination(
            determination_id=sid("determination-1"),
            proceeding_id=sid("proceeding-1"),
            deciding_organization_id=sid("org-2"),
            outcome=AdjudicationOutcome.GRANTED,
            rationale="Supported by the record",
            decided_at=now(),
        )


def test_remedy_requires_distinct_issuer_and_responsible_organization() -> None:
    with pytest.raises(ValueError):
        AdjudicativeRemedy(
            remedy_id=sid("remedy-1"),
            determination_id=sid("determination-1"),
            issuing_organization_id=sid("org-2"),
            responsible_organization_id=sid("org-2"),
            remedy="Corrective action",
            authority_reference="authority-1",
            evidence_reference="evidence-1",
        )
