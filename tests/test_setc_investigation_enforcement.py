from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    EnforcementAppeal, EnforcementDetermination, EnforcementExecutionVerification,
    EnforcementState, FindingDisposition, InvestigationFinding, InvestigationMandate,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_investigation_requires_independent_investigator() -> None:
    with pytest.raises(ValueError, match="independent investigator"):
        InvestigationMandate(sid("mandate"), sid("org"), sid("org"), "conduct", "authority", "evidence")


def test_investigation_finding_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        InvestigationFinding(
            sid("finding"), sid("case"), sid("subject"), sid("investigator"),
            FindingDisposition.SUBSTANTIATED, "finding", (),
        )


def test_material_enforcement_state_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        EnforcementDetermination(
            sid("determination"), sid("finding"), sid("subject"), sid("authority"),
            "sanction", "authority-ref", EnforcementState.IMPOSED, (),
        )


def test_appeal_requires_independent_reviewer() -> None:
    with pytest.raises(ValueError, match="independent reviewer"):
        EnforcementAppeal(sid("appeal"), sid("determination"), sid("org"), sid("org"), "grounds", "evidence")


def test_verified_execution_requires_independent_verifier_and_evidence() -> None:
    with pytest.raises(ValueError, match="independent verifier"):
        EnforcementExecutionVerification(sid("verification"), sid("execution"), sid("org"), sid("org"), True, ("evidence",))

    with pytest.raises(ValueError, match="requires evidence"):
        EnforcementExecutionVerification(sid("verification"), sid("execution"), sid("executor"), sid("verifier"), True, ())
