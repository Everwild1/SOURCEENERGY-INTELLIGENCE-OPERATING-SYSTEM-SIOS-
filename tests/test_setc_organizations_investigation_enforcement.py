from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    EnforcementAppeal,
    EnforcementDetermination,
    EnforcementExecutionVerification,
    EnforcementState,
    FindingDisposition,
    InvestigationFinding,
    InvestigationMandate,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_investigation_mandate_requires_independent_investigator():
    org = sid("org:subject")
    with pytest.raises(ValueError, match="independent investigator"):
        InvestigationMandate(sid("mandate:1"), org, org, "conduct", "authority:1", "evidence:1")


def test_investigation_finding_requires_evidence():
    with pytest.raises(ValueError, match="requires evidence"):
        InvestigationFinding(
            sid("finding:1"), sid("case:1"), sid("org:subject"), sid("org:investigator"),
            FindingDisposition.SUBSTANTIATED, "Control breach established",
        )


def test_material_enforcement_state_requires_evidence():
    with pytest.raises(ValueError, match="material enforcement state"):
        EnforcementDetermination(
            sid("determination:1"), sid("finding:1"), sid("org:subject"), sid("org:authority"),
            "Suspend access", "authority:enforcement", EnforcementState.IMPOSED,
        )


def test_appeal_requires_independent_reviewer():
    org = sid("org:appellant")
    with pytest.raises(ValueError, match="independent reviewer"):
        EnforcementAppeal(sid("appeal:1"), sid("determination:1"), org, org, "procedural error", "evidence:appeal")


def test_verified_execution_requires_independent_verifier_and_evidence():
    executor = sid("org:executor")
    with pytest.raises(ValueError, match="independent verifier"):
        EnforcementExecutionVerification(
            sid("verification:1"), sid("execution:1"), executor, executor, True, ("evidence:1",)
        )

    with pytest.raises(ValueError, match="requires evidence"):
        EnforcementExecutionVerification(
            sid("verification:2"), sid("execution:1"), executor, sid("org:verifier"), True
        )


def test_proposed_enforcement_can_exist_without_execution_evidence():
    determination = EnforcementDetermination(
        sid("determination:2"), sid("finding:2"), sid("org:subject"), sid("org:authority"),
        "Corrective directive", "authority:2", EnforcementState.PROPOSED,
    )
    assert determination.state is EnforcementState.PROPOSED
