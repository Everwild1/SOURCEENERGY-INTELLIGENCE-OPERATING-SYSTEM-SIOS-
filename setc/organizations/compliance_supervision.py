"""Institutional compliance and supervision-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ComplianceSupervisionState(StrEnum):
    REGISTERED = "REGISTERED"
    MONITORED = "MONITORED"
    DEFICIENT = "DEFICIENT"
    ESCALATED = "ESCALATED"
    REMEDIATING = "REMEDIATING"
    COMPLIANT = "COMPLIANT"
    CLOSED = "CLOSED"


class SupervisoryActionState(StrEnum):
    PROPOSED = "PROPOSED"
    ISSUED = "ISSUED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    VERIFIED = "VERIFIED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class ComplianceMandate:
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    supervising_organization_id: SETCIdentifier
    obligation_reference: str
    scope: str
    authority_reference: str
    effective_from: datetime | None = None
    effective_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.supervising_organization_id:
            raise ValueError("compliance mandate requires an independent supervising organization")
        if not self.obligation_reference.strip() or not self.scope.strip() or not self.authority_reference.strip():
            raise ValueError("compliance mandate requires obligation, scope, and authority")
        if self.effective_from and self.effective_until and self.effective_until <= self.effective_from:
            raise ValueError("compliance mandate end must follow start")


@dataclass(frozen=True, slots=True)
class ComplianceEvidenceRecord:
    evidence_id: SETCIdentifier
    mandate_id: SETCIdentifier
    submitting_organization_id: SETCIdentifier
    evidence_reference: str
    submitted_at: datetime
    description: str | None = None

    def __post_init__(self) -> None:
        if not self.evidence_reference.strip():
            raise ValueError("compliance evidence reference cannot be blank")
        if self.description is not None and not self.description.strip():
            raise ValueError("compliance evidence description cannot be blank")


@dataclass(frozen=True, slots=True)
class ComplianceAssessmentRecord:
    assessment_id: SETCIdentifier
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    assessing_organization_id: SETCIdentifier
    state: ComplianceSupervisionState
    rationale: str
    assessed_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.assessing_organization_id:
            raise ValueError("compliance assessment requires an independent assessor")
        if not self.rationale.strip():
            raise ValueError("compliance assessment requires rationale")
        if self.state in {
            ComplianceSupervisionState.DEFICIENT,
            ComplianceSupervisionState.ESCALATED,
            ComplianceSupervisionState.COMPLIANT,
            ComplianceSupervisionState.CLOSED,
        } and not self.evidence_references:
            raise ValueError("material compliance assessment state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("compliance assessment evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class SupervisoryFinding:
    finding_id: SETCIdentifier
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    supervising_organization_id: SETCIdentifier
    finding: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.supervising_organization_id:
            raise ValueError("supervisory finding requires an independent supervisor")
        if not self.finding.strip():
            raise ValueError("supervisory finding cannot be blank")
        if not self.evidence_references:
            raise ValueError("supervisory finding requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("supervisory finding evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class SupervisoryDirective:
    directive_id: SETCIdentifier
    finding_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    authority_reference: str
    evidence_reference: str
    state: SupervisoryActionState = SupervisoryActionState.ISSUED
    due_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.issuing_organization_id == self.responsible_organization_id:
            raise ValueError("supervisory directive requires separation of issuer and responsible organization")
        if not self.action.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("supervisory directive requires action, authority, and evidence")


@dataclass(frozen=True, slots=True)
class ComplianceRemediationRecord:
    remediation_id: SETCIdentifier
    directive_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    state: SupervisoryActionState
    recorded_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("compliance remediation action cannot be blank")
        if self.state in {
            SupervisoryActionState.COMPLETED,
            SupervisoryActionState.VERIFIED,
            SupervisoryActionState.CLOSED,
        } and not self.evidence_references:
            raise ValueError("material remediation state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("remediation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ComplianceVerification:
    verification_id: SETCIdentifier
    remediation_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    verifying_organization_id: SETCIdentifier
    verified: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.responsible_organization_id == self.verifying_organization_id:
            raise ValueError("compliance verification requires an independent verifier")
        if self.verified and not self.evidence_references:
            raise ValueError("verified compliance remediation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("verification evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class SupervisoryEscalation:
    escalation_id: SETCIdentifier
    mandate_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    reason: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("supervisory escalation requires distinct organizations")
        if not self.reason.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("supervisory escalation requires reason, authority, and evidence")
