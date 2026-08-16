"""Institutional risk and compliance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class RiskState(StrEnum):
    IDENTIFIED = "IDENTIFIED"
    ASSESSED = "ASSESSED"
    TREATING = "TREATING"
    MONITORING = "MONITORING"
    ACCEPTED = "ACCEPTED"
    CLOSED = "CLOSED"


class ComplianceState(StrEnum):
    NOT_ASSESSED = "NOT_ASSESSED"
    COMPLIANT = "COMPLIANT"
    PARTIALLY_COMPLIANT = "PARTIALLY_COMPLIANT"
    NONCOMPLIANT = "NONCOMPLIANT"
    REMEDIATING = "REMEDIATING"
    WAIVED = "WAIVED"


@dataclass(frozen=True, slots=True)
class RiskRegisterEntry:
    risk_id: SETCIdentifier
    organization_id: SETCIdentifier
    title: str
    description: str
    owner_organization_id: SETCIdentifier
    state: RiskState = RiskState.IDENTIFIED
    inherent_rating: str | None = None
    residual_rating: str | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.title.strip() or not self.description.strip():
            raise ValueError("risk entry requires title and description")
        if self.inherent_rating is not None and not self.inherent_rating.strip():
            raise ValueError("inherent_rating cannot be blank")
        if self.residual_rating is not None and not self.residual_rating.strip():
            raise ValueError("residual_rating cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("risk evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RiskControlMapping:
    mapping_id: SETCIdentifier
    risk_id: SETCIdentifier
    control_reference: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.control_reference.strip():
            raise ValueError("control_reference cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ComplianceObligation:
    obligation_id: SETCIdentifier
    organization_id: SETCIdentifier
    authority_reference: str
    obligation_reference: str
    description: str

    def __post_init__(self) -> None:
        if not self.authority_reference.strip() or not self.obligation_reference.strip() or not self.description.strip():
            raise ValueError("compliance obligation requires authority, reference, and description")


@dataclass(frozen=True, slots=True)
class ComplianceAssessment:
    assessment_id: SETCIdentifier
    obligation_id: SETCIdentifier
    assessed_organization_id: SETCIdentifier
    assessor_organization_id: SETCIdentifier
    state: ComplianceState
    assessed_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.assessed_organization_id == self.assessor_organization_id:
            raise ValueError("organization cannot self-assess compliance")
        if self.state == ComplianceState.COMPLIANT and not self.evidence_references:
            raise ValueError("compliant assessment requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("assessment evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ComplianceBreach:
    breach_id: SETCIdentifier
    organization_id: SETCIdentifier
    obligation_id: SETCIdentifier
    breach_type: str
    detected_at: datetime
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.breach_type.strip() or not self.evidence_reference.strip():
            raise ValueError("compliance breach requires type and evidence")


@dataclass(frozen=True, slots=True)
class RiskTreatment:
    treatment_id: SETCIdentifier
    risk_id: SETCIdentifier
    action: str
    owner_organization_id: SETCIdentifier
    target_date: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("risk treatment action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class RiskAcceptance:
    acceptance_id: SETCIdentifier
    risk_id: SETCIdentifier
    risk_owner_organization_id: SETCIdentifier
    accepting_organization_id: SETCIdentifier
    rationale: str
    evidence_reference: str
    accepted_at: datetime

    def __post_init__(self) -> None:
        if self.risk_owner_organization_id == self.accepting_organization_id:
            raise ValueError("risk owner cannot self-accept residual risk")
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("risk acceptance requires rationale and evidence")


@dataclass(frozen=True, slots=True)
class RiskMonitoringRecord:
    monitoring_id: SETCIdentifier
    risk_id: SETCIdentifier
    observed_at: datetime
    residual_rating: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.residual_rating.strip() or not self.evidence_reference.strip():
            raise ValueError("risk monitoring requires residual rating and evidence")
