from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    CorrectiveDirective,
    MonitoringObservation,
    MonitoringStatus,
    OversightClosureVerification,
    OversightMandate,
    OversightReviewState,
    SupervisoryReview,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_oversight_mandate_requires_distinct_parties():
    with pytest.raises(ValueError):
        OversightMandate(sid("m1"), sid("org1"), sid("org1"), "treasury", "charter:1")


def test_exception_observation_requires_evidence():
    with pytest.raises(ValueError):
        MonitoringObservation(
            sid("o1"), sid("m1"), sid("regulator"), "metric:liquidity",
            MonitoringStatus.EXCEPTION, datetime.now(timezone.utc),
        )


def test_supervisory_review_requires_independent_reviewer():
    with pytest.raises(ValueError):
        SupervisoryReview(sid("r1"), sid("m1"), sid("org1"), sid("org1"))


def test_material_review_state_requires_evidence():
    with pytest.raises(ValueError):
        SupervisoryReview(
            sid("r1"), sid("m1"), sid("org1"), sid("regulator"),
            state=OversightReviewState.DIRECTIVE_ISSUED,
        )


def test_corrective_directive_requires_distinct_issuer_and_responsible_party():
    with pytest.raises(ValueError):
        CorrectiveDirective(
            sid("d1"), sid("r1"), sid("org1"), sid("org1"), "restore control",
            "authority:1", "evidence:1",
        )


def test_verified_closure_requires_independent_verifier_and_evidence():
    with pytest.raises(ValueError):
        OversightClosureVerification(sid("v1"), sid("d1"), sid("org1"), sid("org1"), True, ("e:1",))
    with pytest.raises(ValueError):
        OversightClosureVerification(sid("v2"), sid("d1"), sid("org1"), sid("auditor"), True)


def test_valid_monitoring_observation_preserves_evidence():
    observation = MonitoringObservation(
        sid("o1"), sid("m1"), sid("regulator"), "metric:liquidity",
        MonitoringStatus.EXCEPTION, datetime.now(timezone.utc), ("evidence:42",),
    )
    assert observation.evidence_references == ("evidence:42",)
