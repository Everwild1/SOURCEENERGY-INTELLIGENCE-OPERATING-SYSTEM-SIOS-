"""Institutional remediation and resolution-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class RemediationState(StrEnum):
    REQUIRED = "REQUIRED"
    PLANNED = "PLANNED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    VERIFIED = "VERIFIED"
    REOPENED = "REOPENED"
    CLOSED = "CLOSED"


class ResolutionState(StrEnum):
    OPEN = "OPEN"
    PROPOSED = "PROPOSED"
    APPROVED = "APPROVED"
    IMPLEMENTING = "IMPLEMENTING"
    RESOLVED = "RESOLVED"
    REOPENED = "REOPENED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class RemediationObligation:
    obligation_id: SETCIdentifier
    source_reference: str
    subject_organization_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    requirement: str
    authority_reference: str
    state: RemediationState = RemediationState.REQUIRED
    due_at: datetime | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.source_reference.strip() or not self.requirement.strip() or not self.authority_reference.strip():
            raise ValueError("remediation obligation requires source, requirement, and authority")
        if self.state in {RemediationState.COMPLETED, RemediationState.VERIFIED, RemediationState.CLOSED} and not self.evidence_references:
            raise ValueError("material remediation state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("remediation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ResolutionPlan:
    plan_id: SETCIdentifier
    obligation_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    plan_reference: str
    objective: str
    approved_by_organization_id: SETCIdentifier | None = None
    approved_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.plan_reference.strip() or not self.objective.strip():
            raise ValueError("resolution plan requires reference and objective")
        if self.approved_by_organization_id == self.responsible_organization_id:
            raise ValueError("responsible organization cannot self-approve resolution plan")
        if self.approved_at is not None and self.approved_by_organization_id is None:
            raise ValueError("approved_at requires approving organization")


@dataclass(frozen=True, slots=True)
class ResolutionMilestone:
    milestone_id: SETCIdentifier
    plan_id: SETCIdentifier
    description: str
    due_at: datetime | None = None
    completed_at: datetime | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.description.strip():
            raise ValueError("resolution milestone description cannot be blank")
        if self.completed_at is not None and not self.evidence_references:
            raise ValueError("completed milestone requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("milestone evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RemediationCompletionRecord:
    completion_id: SETCIdentifier
    obligation_id: SETCIdentifier
    completing_organization_id: SETCIdentifier
    completed_at: datetime
    outcome: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.outcome.strip():
            raise ValueError("remediation completion outcome cannot be blank")
        if not self.evidence_references:
            raise ValueError("remediation completion requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("completion evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RemediationValidation:
    validation_id: SETCIdentifier
    obligation_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    validating_organization_id: SETCIdentifier
    validated: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.responsible_organization_id == self.validating_organization_id:
            raise ValueError("remediation validation requires an independent validator")
        if self.validated and not self.evidence_references:
            raise ValueError("validated remediation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("validation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RemediationEscalation:
    escalation_id: SETCIdentifier
    obligation_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("remediation escalation requires distinct organizations")
        if not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("remediation escalation requires reason and evidence")


@dataclass(frozen=True, slots=True)
class ResolutionRecord:
    resolution_id: SETCIdentifier
    obligation_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    resolving_organization_id: SETCIdentifier
    state: ResolutionState
    rationale: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.rationale.strip():
            raise ValueError("resolution record requires rationale")
        if self.state in {ResolutionState.RESOLVED, ResolutionState.CLOSED} and not self.evidence_references:
            raise ValueError("resolved or closed resolution requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("resolution evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ResolutionReopening:
    reopening_id: SETCIdentifier
    resolution_id: SETCIdentifier
    reopening_organization_id: SETCIdentifier
    reason: str
    authority_reference: str
    evidence_reference: str
    reopened_at: datetime

    def __post_init__(self) -> None:
        if not self.reason.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("resolution reopening requires reason, authority, and evidence")
