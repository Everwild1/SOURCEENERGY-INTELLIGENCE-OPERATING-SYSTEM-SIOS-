from datetime import datetime, timezone

import pytest

from setc.core import SETCIdentifier
from setc.organizations.risk_controls import (
    ControlAssessment, ControlEffectiveness, ControlException, ControlObjective,
    InstitutionalRisk, RiskControlLink, RiskDecisionLink, RiskDisposition,
    RiskEscalation, RiskTreatmentPlan,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_risk_requires_material_description():
    with pytest.raises(ValueError):
        InstitutionalRisk(sid("risk:1"), sid("org:1"), "R-1", "Risk", " ", sid("org:owner"), "HIGH")


def test_control_owner_cannot_independently_self_assess():
    with pytest.raises(ValueError):
        ControlAssessment(
            sid("assessment:1"), sid("control:1"), sid("org:owner"), sid("org:owner"),
            ControlEffectiveness.EFFECTIVE, datetime.now(timezone.utc), ("evidence:1",),
        )


def test_effectiveness_requires_evidence():
    with pytest.raises(ValueError):
        ControlAssessment(
            sid("assessment:1"), sid("control:1"), sid("org:owner"), sid("org:assessor"),
            ControlEffectiveness.EFFECTIVE, datetime.now(timezone.utc), (),
        )


def test_not_assessed_does_not_fabricate_evidence():
    assessment = ControlAssessment(
        sid("assessment:1"), sid("control:1"), sid("org:owner"), sid("org:assessor"),
        ControlEffectiveness.NOT_ASSESSED, datetime.now(timezone.utc), (),
    )
    assert assessment.effectiveness == ControlEffectiveness.NOT_ASSESSED


def test_risk_escalation_requires_distinct_parties():
    with pytest.raises(ValueError):
        RiskEscalation(sid("esc:1"), sid("risk:1"), sid("org:1"), sid("org:1"), "material", "evidence:1")


def test_control_exception_requires_authority_and_evidence():
    with pytest.raises(ValueError):
        ControlException(sid("ex:1"), sid("control:1"), "subject", "reason", sid("org:2"), " ", "evidence:1")


def test_risk_control_and_decision_links_preserve_provenance():
    control_link = RiskControlLink(sid("link:1"), sid("risk:1"), sid("control:1"), "mitigates", "evidence:1")
    decision_link = RiskDecisionLink(sid("link:2"), sid("risk:1"), sid("decision:1"), "informed decision", "evidence:2")
    assert control_link.risk_id == decision_link.risk_id


def test_risk_and_control_primitives_construct():
    risk = InstitutionalRisk(
        sid("risk:1"), sid("org:1"), "R-1", "Liquidity", "Liquidity pressure",
        sid("org:owner"), "HIGH", "MODERATE", RiskDisposition.MONITORING, ("evidence:risk",),
    )
    control = ControlObjective(sid("control:1"), sid("org:1"), "C-1", "Maintain liquidity buffer", sid("org:control"))
    treatment = RiskTreatmentPlan(sid("treatment:1"), risk.risk_id, sid("org:owner"), "Increase reserve")
    assert control.objective and treatment.action
