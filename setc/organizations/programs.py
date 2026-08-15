"""Governed program and cohort primitives for the SETC Organizations domain."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum

from setc.core import SETCIdentifier


class ProgramType(str, Enum):
    INCUBATION = "INCUBATION"
    ACCELERATION = "ACCELERATION"
    ENTREPRENEURSHIP = "ENTREPRENEURSHIP"
    RESEARCH = "RESEARCH"
    FELLOWSHIP = "FELLOWSHIP"
    GRANT = "GRANT"
    PILOT = "PILOT"
    CAPACITY_BUILDING = "CAPACITY_BUILDING"


class ProgramState(str, Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class CohortState(str, Enum):
    PLANNED = "PLANNED"
    ENROLLING = "ENROLLING"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class ParticipationState(str, Enum):
    NOMINATED = "NOMINATED"
    APPLIED = "APPLIED"
    ADMITTED = "ADMITTED"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    WITHDRAWN = "WITHDRAWN"
    REMOVED = "REMOVED"


@dataclass(frozen=True, slots=True)
class Program:
    program_id: SETCIdentifier
    operating_organization_id: SETCIdentifier
    name: str
    program_type: ProgramType
    state: ProgramState = ProgramState.DRAFT
    sponsor_organization_ids: tuple[SETCIdentifier, ...] = field(default_factory=tuple)
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("program name cannot be blank")
        if self.operating_organization_id in self.sponsor_organization_ids:
            raise ValueError("operator must not be duplicated as a sponsor")
        if len(set(self.sponsor_organization_ids)) != len(self.sponsor_organization_ids):
            raise ValueError("program sponsors must be unique")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence reference cannot be blank")


@dataclass(frozen=True, slots=True)
class Cohort:
    cohort_id: SETCIdentifier
    program_id: SETCIdentifier
    name: str
    state: CohortState = CohortState.PLANNED
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("cohort name cannot be blank")
        if self.starts_at and self.ends_at and self.ends_at < self.starts_at:
            raise ValueError("cohort end cannot precede start")


@dataclass(frozen=True, slots=True)
class ProgramParticipation:
    participation_id: SETCIdentifier
    program_id: SETCIdentifier
    participant_organization_id: SETCIdentifier
    cohort_id: SETCIdentifier | None = None
    state: ParticipationState = ParticipationState.APPLIED
    admitted_at: datetime | None = None
    completed_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.admitted_at and self.completed_at and self.completed_at < self.admitted_at:
            raise ValueError("completion cannot precede admission")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence reference cannot be blank")
