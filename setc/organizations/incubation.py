"""Incubation operations governed by SETC-112."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class IncubationState(StrEnum):
    APPLICATION = "APPLICATION"
    ELIGIBILITY_REVIEW = "ELIGIBILITY_REVIEW"
    SELECTION_REVIEW = "SELECTION_REVIEW"
    ADMITTED = "ADMITTED"
    PRE_INCUBATION = "PRE_INCUBATION"
    ACTIVE_INCUBATION = "ACTIVE_INCUBATION"
    MILESTONE_REVIEW = "MILESTONE_REVIEW"
    GRADUATION_REVIEW = "GRADUATION_REVIEW"
    GRADUATED = "GRADUATED"
    EXTENDED = "EXTENDED"
    PAUSED = "PAUSED"
    SUSPENDED = "SUSPENDED"
    WITHDRAWN = "WITHDRAWN"
    TERMINATED = "TERMINATED"
    ARCHIVED = "ARCHIVED"


class IncubationMilestoneState(StrEnum):
    PLANNED = "PLANNED"
    SUBMITTED = "SUBMITTED"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    WAIVED = "WAIVED"


class HandoffType(StrEnum):
    ACCELERATION = "ACCELERATION"
    VENTURE_FORMATION = "VENTURE_FORMATION"
    COMMERCIALIZATION = "COMMERCIALIZATION"
    CAPITAL_READINESS = "CAPITAL_READINESS"
    PROCUREMENT_READINESS = "PROCUREMENT_READINESS"
    ENTERPRISE_DEPLOYMENT = "ENTERPRISE_DEPLOYMENT"


@dataclass(frozen=True, slots=True)
class IncubationApplication:
    application_id: SETCIdentifier
    program_id: SETCIdentifier
    applicant_organization_id: SETCIdentifier
    state: IncubationState = IncubationState.APPLICATION
    submitted_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class IncubationParticipation:
    participation_id: SETCIdentifier
    program_id: SETCIdentifier
    participant_organization_id: SETCIdentifier
    cohort_id: SETCIdentifier | None = None
    state: IncubationState = IncubationState.ADMITTED
    admitted_at: datetime | None = None
    completed_at: datetime | None = None
    research_reference: str | None = None
    ip_reference: str | None = None

    def __post_init__(self) -> None:
        if self.admitted_at and self.completed_at and self.completed_at < self.admitted_at:
            raise ValueError("completion cannot precede admission")
        for value, label in (
            (self.research_reference, "research_reference"),
            (self.ip_reference, "ip_reference"),
        ):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class MentorAssignment:
    assignment_id: SETCIdentifier
    participation_id: SETCIdentifier
    mentor_organization_id: SETCIdentifier
    scope: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.scope.strip():
            raise ValueError("mentor scope cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ResourceAccessGrant:
    access_grant_id: SETCIdentifier
    participation_id: SETCIdentifier
    resource_type: str
    granted_by_organization_id: SETCIdentifier
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.resource_type.strip():
            raise ValueError("resource_type cannot be blank")
        if self.starts_at and self.ends_at and self.ends_at < self.starts_at:
            raise ValueError("resource access end cannot precede start")


@dataclass(frozen=True, slots=True)
class IncubationMilestone:
    milestone_id: SETCIdentifier
    participation_id: SETCIdentifier
    name: str
    state: IncubationMilestoneState = IncubationMilestoneState.PLANNED
    evidence_reference: str | None = None
    unresolved_risk: str | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("milestone name cannot be blank")
        for value, label in (
            (self.evidence_reference, "evidence_reference"),
            (self.unresolved_risk, "unresolved_risk"),
        ):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class ProgramHandoff:
    handoff_id: SETCIdentifier
    participation_id: SETCIdentifier
    handoff_type: HandoffType
    target_organization_id: SETCIdentifier | None = None
    evidence_reference: str | None = None
    unresolved_risk: str | None = None

    def __post_init__(self) -> None:
        for value, label in (
            (self.evidence_reference, "evidence_reference"),
            (self.unresolved_risk, "unresolved_risk"),
        ):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")
