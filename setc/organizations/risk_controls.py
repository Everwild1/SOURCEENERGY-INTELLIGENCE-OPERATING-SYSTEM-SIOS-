"""Institutional risk and control-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ControlEffectiveness(StrEnum):
    NOT_ASSESSED = "NOT_ASSESSED"
    INEFFECTIVE = "INEFFECTIVE"
    PARTIALLY_EFFECTIVE = "PARTIALLY_EFFECTIVE"
    EFFECTIVE = "EFFECTIVE"


class RiskDisposition(StrEnum):
    OPEN = "OPEN"
    TREATING = "TREATING"
    MONITORING = "MONITORING"
    ACCEPTED = "ACCEPTED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class InstitutionalRisk:
    risk_id: SETCIdentifier
    organization_id: SETCIdentifier
    risk_reference: str
    title: str
    description: str
    owner_organization_id: SETCIdentifier
    inherent_rating: str
    residual_rating: str | None = None
    disposition: RiskDisposition = RiskDisposition.OPEN
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.risk_reference.strip() or not self.title.strip() or not self.description.strip():
            raise ValueError("institutional risk requires reference, title, and description")
        if not self.inherent_rating.strip():
            raise ValueError("inherent risk rating cannot be blank")
        if self.residual_rating is not None and not self.residual_rating.strip():
            raise ValueError("residual risk rating cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("risk evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ControlObjective:
    control_id: SETCIdentifier
    organization_id: SETCIdentifier
    control_reference: str
    objective: str
    owner_organization_id: SETCIdentifier
    policy_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.control_reference.strip() or not self.objective.strip():
            raise ValueError("control objective requires reference and objective")
        if self.policy_reference is not None and not self.policy_reference.strip():
            raise ValueError("policy_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class RiskControlLink:
    link_id: SETCIdentifier
    risk_id: SETCIdentifier
    control_id: SETCIdentifier
    rationale: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("risk-control link requires rationale and evidence")


@dataclass(frozen=True, slots=True)
class ControlAssessment:
    assessment_id: SETCIdentifier
    control_id: SETCIdentifier
    control_owner_organization_id: SETCIdentifier
    assessor_organization_id: SETCIdentifier
    effectiveness: ControlEffectiveness
    assessed_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.control_owner_organization_id == self.assessor_organization_id:
            raise ValueError("control owner cannot independently assess its own control")
        if self.effectiveness != ControlEffectiveness.NOT_ASSESSED and not self.evidence_references:
            raise ValueError("assessed control effectiveness requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("control assessment evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ControlException:
    exception_id: SETCIdentifier
    control_id: SETCIdentifier
    subject_reference: str
    rationale: str
    approving_organization_id: SETCIdentifier
    authority_reference: str
    evidence_reference: str
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.rationale.strip():
            raise ValueError("control exception requires subject and rationale")
        if not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("control exception requires authority and evidence")


@dataclass(frozen=True, slots=True)
class RiskTreatmentPlan:
    treatment_id: SETCIdentifier
    risk_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    target_date: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("risk treatment action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class RiskEscalation:
    escalation_id: SETCIdentifier
    risk_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("risk escalation requires distinct organizations")
        if not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("risk escalation requires reason and evidence")


@dataclass(frozen=True, slots=True)
class RiskDecisionLink:
    link_id: SETCIdentifier
    risk_id: SETCIdentifier
    decision_id: SETCIdentifier
    rationale: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("risk-decision link requires rationale and evidence")
