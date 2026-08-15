"""Foundation and philanthropic-capital primitives governed by SETC-111."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from enum import StrEnum

from setc.core import SETCIdentifier


class PhilanthropicInstrumentType(StrEnum):
    GRANT = "GRANT"
    CHALLENGE_GRANT = "CHALLENGE_GRANT"
    MATCHING_GRANT = "MATCHING_GRANT"
    RECOVERABLE_GRANT = "RECOVERABLE_GRANT"
    PROGRAM_RELATED_INVESTMENT = "PROGRAM_RELATED_INVESTMENT"
    MISSION_RELATED_INVESTMENT = "MISSION_RELATED_INVESTMENT"
    GUARANTEE = "GUARANTEE"
    FIRST_LOSS_CAPITAL = "FIRST_LOSS_CAPITAL"
    TECHNICAL_ASSISTANCE = "TECHNICAL_ASSISTANCE"
    RESEARCH_FUNDING = "RESEARCH_FUNDING"
    COMMERCIALIZATION_SUPPORT = "COMMERCIALIZATION_SUPPORT"


class AwardState(StrEnum):
    DRAFT = "DRAFT"
    RECOMMENDED = "RECOMMENDED"
    APPROVED = "APPROVED"
    COMMITTED = "COMMITTED"
    PARTIALLY_DISBURSED = "PARTIALLY_DISBURSED"
    DISBURSED = "DISBURSED"
    SUSPENDED = "SUSPENDED"
    RECOVERED = "RECOVERED"
    CLOSED = "CLOSED"
    CANCELLED = "CANCELLED"


class MilestoneState(StrEnum):
    PLANNED = "PLANNED"
    SUBMITTED = "SUBMITTED"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    WAIVED = "WAIVED"


@dataclass(frozen=True, slots=True)
class FoundationProfile:
    foundation_organization_id: SETCIdentifier
    mission: str
    thematic_priorities: tuple[str, ...] = field(default_factory=tuple)
    geographic_mandates: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.mission.strip():
            raise ValueError("foundation mission cannot be blank")
        if any(not value.strip() for value in self.thematic_priorities):
            raise ValueError("foundation priorities cannot contain blanks")
        if any(not value.strip() for value in self.geographic_mandates):
            raise ValueError("foundation geographic mandates cannot contain blanks")


@dataclass(frozen=True, slots=True)
class FundingInstrument:
    instrument_id: SETCIdentifier
    foundation_organization_id: SETCIdentifier
    instrument_type: PhilanthropicInstrumentType
    name: str
    currency: str | None = None
    maximum_amount: Decimal | None = None
    restrictions: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("funding instrument name cannot be blank")
        if self.maximum_amount is not None and self.maximum_amount <= 0:
            raise ValueError("maximum_amount must be positive")
        if self.currency is not None and len(self.currency.strip()) != 3:
            raise ValueError("currency must be a three-letter code")
        if any(not value.strip() for value in self.restrictions):
            raise ValueError("instrument restrictions cannot contain blanks")


@dataclass(frozen=True, slots=True)
class GrantAward:
    award_id: SETCIdentifier
    foundation_organization_id: SETCIdentifier
    recipient_organization_id: SETCIdentifier
    instrument_id: SETCIdentifier
    amount: Decimal
    currency: str
    state: AwardState = AwardState.DRAFT
    program_id: SETCIdentifier | None = None
    research_reference: str | None = None
    venture_reference: str | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.foundation_organization_id == self.recipient_organization_id:
            raise ValueError("foundation cannot award itself")
        if self.amount <= 0:
            raise ValueError("award amount must be positive")
        if len(self.currency.strip()) != 3:
            raise ValueError("currency must be a three-letter code")
        for value, label in (
            (self.research_reference, "research_reference"),
            (self.venture_reference, "venture_reference"),
            (self.evidence_reference, "evidence_reference"),
        ):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class GrantMilestone:
    milestone_id: SETCIdentifier
    award_id: SETCIdentifier
    name: str
    state: MilestoneState = MilestoneState.PLANNED
    due_date: date | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("milestone name cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ImpactReport:
    report_id: SETCIdentifier
    award_id: SETCIdentifier
    metric_name: str
    metric_value: Decimal
    unit: str
    verified: bool = False
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.metric_name.strip():
            raise ValueError("impact metric name cannot be blank")
        if not self.unit.strip():
            raise ValueError("impact unit cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
