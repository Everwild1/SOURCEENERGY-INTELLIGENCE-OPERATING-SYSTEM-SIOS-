"""Institutional appeals and review-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class AppealState(StrEnum):
    FILED = "FILED"
    ACCEPTED = "ACCEPTED"
    DISMISSED = "DISMISSED"
    UNDER_REVIEW = "UNDER_REVIEW"
    DECIDED = "DECIDED"
    CLOSED = "CLOSED"


class ReviewOutcome(StrEnum):
    AFFIRMED = "AFFIRMED"
    MODIFIED = "MODIFIED"
    REVERSED = "REVERSED"
    REMANDED = "REMANDED"
    DISMISSED = "DISMISSED"


@dataclass(frozen=True, slots=True)
class AppealRight:
    appeal_right_id: SETCIdentifier
    source_reference: str
    subject_organization_id: SETCIdentifier
    eligible_appellant_organization_id: SETCIdentifier
    reviewing_organization_id: SETCIdentifier
    authority_reference: str
    filing_deadline: datetime | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.reviewing_organization_id:
            raise ValueError("appeal right requires an independent reviewing organization")
        if not self.source_reference.strip() or not self.authority_reference.strip():
            raise ValueError("appeal right requires source and authority")


@dataclass(frozen=True, slots=True)
class AppealFiling:
    appeal_id: SETCIdentifier
    appeal_right_id: SETCIdentifier
    appellant_organization_id: SETCIdentifier
    grounds: str
    filed_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    state: AppealState = AppealState.FILED

    def __post_init__(self) -> None:
        if not self.grounds.strip():
            raise ValueError("appeal filing requires grounds")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("appeal evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AppealStandingDetermination:
    standing_id: SETCIdentifier
    appeal_id: SETCIdentifier
    determining_organization_id: SETCIdentifier
    has_standing: bool
    rationale: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("standing determination requires rationale and evidence")


@dataclass(frozen=True, slots=True)
class AppealStay:
    stay_id: SETCIdentifier
    appeal_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    action_reference: str
    rationale: str
    authority_reference: str
    effective_at: datetime
    expires_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.action_reference.strip() or not self.rationale.strip() or not self.authority_reference.strip():
            raise ValueError("appeal stay requires action, rationale, and authority")
        if self.expires_at is not None and self.expires_at <= self.effective_at:
            raise ValueError("appeal stay expiry must follow effective time")


@dataclass(frozen=True, slots=True)
class ReviewRecord:
    review_id: SETCIdentifier
    appeal_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    reviewing_organization_id: SETCIdentifier
    scope: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.reviewing_organization_id:
            raise ValueError("appeal review requires an independent reviewer")
        if not self.scope.strip():
            raise ValueError("appeal review scope cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("review evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ReviewDetermination:
    determination_id: SETCIdentifier
    review_id: SETCIdentifier
    deciding_organization_id: SETCIdentifier
    outcome: ReviewOutcome
    rationale: str
    decided_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.rationale.strip():
            raise ValueError("review determination requires rationale")
        if not self.evidence_references:
            raise ValueError("review determination requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("review determination evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ReviewRemand:
    remand_id: SETCIdentifier
    determination_id: SETCIdentifier
    remanding_organization_id: SETCIdentifier
    receiving_organization_id: SETCIdentifier
    instruction: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.remanding_organization_id == self.receiving_organization_id:
            raise ValueError("review remand requires distinct organizations")
        if not self.instruction.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("review remand requires instruction, authority, and evidence")


@dataclass(frozen=True, slots=True)
class AppealFinalityRecord:
    finality_id: SETCIdentifier
    appeal_id: SETCIdentifier
    finalizing_organization_id: SETCIdentifier
    final_at: datetime
    rationale: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("appeal finality requires rationale and evidence")
