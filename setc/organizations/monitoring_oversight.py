"""Institutional monitoring and oversight-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class MonitoringStatus(StrEnum):
    NORMAL = "NORMAL"
    WATCH = "WATCH"
    EXCEPTION = "EXCEPTION"
    ESCALATED = "ESCALATED"
    CLOSED = "CLOSED"


class OversightReviewState(StrEnum):
    OPEN = "OPEN"
    UNDER_REVIEW = "UNDER_REVIEW"
    DIRECTIVE_ISSUED = "DIRECTIVE_ISSUED"
    VERIFIED = "VERIFIED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class OversightMandate:
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    overseeing_organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    effective_from: datetime | None = None
    effective_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.overseeing_organization_id:
            raise ValueError("oversight mandate requires distinct subject and overseer organizations")
        if not self.scope.strip() or not self.authority_reference.strip():
            raise ValueError("oversight mandate requires scope and authority")
        if self.effective_from and self.effective_until and self.effective_until <= self.effective_from:
            raise ValueError("oversight mandate end must follow start")


@dataclass(frozen=True, slots=True)
class MonitoringThreshold:
    threshold_id: SETCIdentifier
    mandate_id: SETCIdentifier
    metric_reference: str
    comparator: str
    threshold_value: str
    escalation_required: bool = False

    def __post_init__(self) -> None:
        if not self.metric_reference.strip() or not self.comparator.strip() or not self.threshold_value.strip():
            raise ValueError("monitoring threshold requires metric, comparator, and value")


@dataclass(frozen=True, slots=True)
class MonitoringObservation:
    observation_id: SETCIdentifier
    mandate_id: SETCIdentifier
    observing_organization_id: SETCIdentifier
    subject_reference: str
    status: MonitoringStatus
    observed_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.subject_reference.strip():
            raise ValueError("monitoring observation subject cannot be blank")
        if self.status in {MonitoringStatus.EXCEPTION, MonitoringStatus.ESCALATED} and not self.evidence_references:
            raise ValueError("exception or escalated monitoring observation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("monitoring evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class OversightException:
    exception_id: SETCIdentifier
    observation_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    description: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.description.strip():
            raise ValueError("oversight exception description cannot be blank")
        if not self.evidence_references:
            raise ValueError("oversight exception requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("oversight exception evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class SupervisoryReview:
    review_id: SETCIdentifier
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    reviewing_organization_id: SETCIdentifier
    state: OversightReviewState = OversightReviewState.OPEN
    finding: str | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.reviewing_organization_id:
            raise ValueError("supervisory review requires an independent reviewing organization")
        if self.finding is not None and not self.finding.strip():
            raise ValueError("supervisory review finding cannot be blank")
        if self.state in {OversightReviewState.DIRECTIVE_ISSUED, OversightReviewState.VERIFIED, OversightReviewState.CLOSED} and not self.evidence_references:
            raise ValueError("material supervisory review state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("supervisory review evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class OversightEscalation:
    escalation_id: SETCIdentifier
    review_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("oversight escalation requires distinct organizations")
        if not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("oversight escalation requires reason and evidence")


@dataclass(frozen=True, slots=True)
class CorrectiveDirective:
    directive_id: SETCIdentifier
    review_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    authority_reference: str
    evidence_reference: str
    due_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.issuing_organization_id == self.responsible_organization_id:
            raise ValueError("corrective directive requires distinct issuer and responsible organization")
        if not self.action.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("corrective directive requires action, authority, and evidence")


@dataclass(frozen=True, slots=True)
class OversightClosureVerification:
    verification_id: SETCIdentifier
    directive_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    verified: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.verifier_organization_id:
            raise ValueError("oversight closure verification requires an independent verifier")
        if self.verified and not self.evidence_references:
            raise ValueError("verified oversight closure requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("closure verification evidence references cannot contain blanks")
