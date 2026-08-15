"""Acceleration operations governed by SETC-113."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class AccelerationState(StrEnum):
    APPLICATION = "APPLICATION"
    ELIGIBILITY_REVIEW = "ELIGIBILITY_REVIEW"
    SELECTION_REVIEW = "SELECTION_REVIEW"
    ADMITTED = "ADMITTED"
    ONBOARDING = "ONBOARDING"
    ACTIVE_ACCELERATION = "ACTIVE_ACCELERATION"
    TRACTION_REVIEW = "TRACTION_REVIEW"
    COMMERCIALIZATION_REVIEW = "COMMERCIALIZATION_REVIEW"
    INVESTOR_PREPARATION = "INVESTOR_PREPARATION"
    PROCUREMENT_PREPARATION = "PROCUREMENT_PREPARATION"
    GRADUATION_REVIEW = "GRADUATION_REVIEW"
    GRADUATED = "GRADUATED"
    EXTENDED = "EXTENDED"
    PAUSED = "PAUSED"
    SUSPENDED = "SUSPENDED"
    WITHDRAWN = "WITHDRAWN"
    TERMINATED = "TERMINATED"
    ARCHIVED = "ARCHIVED"


class EvidenceQuality(StrEnum):
    SELF_REPORTED = "SELF_REPORTED"
    INTERNALLY_REVIEWED = "INTERNALLY_REVIEWED"
    VERIFIED = "VERIFIED"
    EXTERNALLY_ATTESTED = "EXTERNALLY_ATTESTED"


class PreparationState(StrEnum):
    NOT_STARTED = "NOT_STARTED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    BLOCKED = "BLOCKED"


@dataclass(frozen=True, slots=True)
class AccelerationApplication:
    application_id: SETCIdentifier
    program_id: SETCIdentifier
    applicant_organization_id: SETCIdentifier
    state: AccelerationState = AccelerationState.APPLICATION
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class AccelerationParticipation:
    participation_id: SETCIdentifier
    program_id: SETCIdentifier
    participant_organization_id: SETCIdentifier
    cohort_id: SETCIdentifier | None = None
    state: AccelerationState = AccelerationState.ADMITTED
    admitted_at: datetime | None = None
    completed_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.admitted_at and self.completed_at and self.completed_at < self.admitted_at:
            raise ValueError("completion cannot precede admission")


@dataclass(frozen=True, slots=True)
class TractionEvidence:
    evidence_id: SETCIdentifier
    participation_id: SETCIdentifier
    evidence_type: str
    quality: EvidenceQuality = EvidenceQuality.SELF_REPORTED
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.evidence_type.strip():
            raise ValueError("evidence_type cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class CommercializationMilestone:
    milestone_id: SETCIdentifier
    participation_id: SETCIdentifier
    name: str
    evidence_reference: str | None = None
    unresolved_risk: str | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("milestone name cannot be blank")
        for value, label in ((self.evidence_reference, "evidence_reference"), (self.unresolved_risk, "unresolved_risk")):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class StrategicPartnerEngagement:
    engagement_id: SETCIdentifier
    participation_id: SETCIdentifier
    partner_organization_id: SETCIdentifier
    scope: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.scope.strip():
            raise ValueError("partner scope cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ReadinessPreparation:
    preparation_id: SETCIdentifier
    participation_id: SETCIdentifier
    preparation_type: str
    state: PreparationState = PreparationState.NOT_STARTED
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.preparation_type not in {"INVESTOR", "PROCUREMENT"}:
            raise ValueError("preparation_type must be INVESTOR or PROCUREMENT")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class CapitalReadinessReferral:
    referral_id: SETCIdentifier
    participation_id: SETCIdentifier
    target_organization_id: SETCIdentifier | None = None
    evidence_reference: str | None = None
    unresolved_risk: str | None = None

    def __post_init__(self) -> None:
        for value, label in ((self.evidence_reference, "evidence_reference"), (self.unresolved_risk, "unresolved_risk")):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")
