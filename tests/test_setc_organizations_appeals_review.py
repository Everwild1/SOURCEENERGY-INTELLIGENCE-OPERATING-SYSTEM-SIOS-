from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    AppealFinalityRecord,
    AppealRight,
    AppealStay,
    ReviewDetermination,
    ReviewOutcome,
    ReviewRecord,
    ReviewRemand,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def now() -> datetime:
    return datetime.now(timezone.utc)


def test_appeal_right_requires_independent_reviewer() -> None:
    with pytest.raises(ValueError, match="independent reviewing organization"):
        AppealRight(sid("ar1"), "decision:1", sid("org1"), sid("org2"), sid("org1"), "authority:1")


def test_review_requires_independent_reviewer() -> None:
    with pytest.raises(ValueError, match="independent reviewer"):
        ReviewRecord(sid("rv1"), sid("ap1"), sid("org1"), sid("org1"), "merits")


def test_review_determination_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        ReviewDetermination(sid("d1"), sid("rv1"), sid("org2"), ReviewOutcome.AFFIRMED, "supported", now())


def test_stay_expiry_must_follow_effective_time() -> None:
    t = now()
    with pytest.raises(ValueError, match="expiry must follow"):
        AppealStay(sid("s1"), sid("ap1"), sid("org2"), "action:1", "preserve status", "authority:1", t, t)


def test_remand_requires_distinct_organizations() -> None:
    with pytest.raises(ValueError, match="distinct organizations"):
        ReviewRemand(sid("rm1"), sid("d1"), sid("org2"), sid("org2"), "reconsider", "authority:1", "evidence:1")


def test_finality_requires_evidence() -> None:
    with pytest.raises(ValueError, match="finality requires rationale and evidence"):
        AppealFinalityRecord(sid("f1"), sid("ap1"), sid("org2"), now(), "final", "")
