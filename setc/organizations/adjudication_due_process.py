"""Institutional adjudication and due-process governance for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ProceedingState(StrEnum):
    INITIATED = "INITIATED"
    NOTICE_SERVED = "NOTICE_SERVED"
    HEARING = "HEARING"
    SUBMITTED = "SUBMITTED"
    DECIDED = "DECIDED"
    CLOSED = "CLOSED"


class AdjudicationOutcome(StrEnum):
    GRANTED = "GRANTED"
    DENIED = "DENIED"
    PARTIALLY_GRANTED = "PARTIALLY_GRANTED"
    DISMISSED = "DISMISSED"


@dataclass(frozen=True, slots=True)
class AdjudicativeProceeding:
    proceeding_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    adjudicating_organization_id: SETCIdentifier
    matter_reference: str
    jurisdiction_reference: str
    state: ProceedingState = ProceedingState.INITIATED

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.adjudicating_organization_id:
            raise ValueError("adjudication requires an independent adjudicating organization")
        if not self.matter_reference.strip() or not self.jurisdiction_reference.strip():
            raise ValueError("proceeding requires matter and jurisdiction references")


@dataclass(frozen=True, slots=True)
class ProceedingNotice:
    notice_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    recipient_organization_id: SETCIdentifier
    notice_reference: str
    served_at: datetime
    service_evidence_reference: str

    def __post_init__(self) -> None:
        if not self.notice_reference.strip() or not self.service_evidence_reference.strip():
            raise ValueError("proceeding notice requires notice and service evidence")


@dataclass(frozen=True, slots=True)
class ProceduralRight:
    right_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    beneficiary_organization_id: SETCIdentifier
    right: str
    authority_reference: str

    def __post_init__(self) -> None:
        if not self.right.strip() or not self.authority_reference.strip():
            raise ValueError("procedural right requires right and authority")


@dataclass(frozen=True, slots=True)
class AdjudicatorRecusal:
    recusal_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    adjudicating_organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("adjudicator recusal requires reason and evidence")


@dataclass(frozen=True, slots=True)
class HearingRecord:
    hearing_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    hearing_authority_organization_id: SETCIdentifier
    held_at: datetime
    record_reference: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.record_reference.strip():
            raise ValueError("hearing record reference cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("hearing evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AdjudicativeFinding:
    finding_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    finding: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.finding.strip():
            raise ValueError("adjudicative finding cannot be blank")
        if not self.evidence_references:
            raise ValueError("adjudicative finding requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("finding evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AdjudicativeDetermination:
    determination_id: SETCIdentifier
    proceeding_id: SETCIdentifier
    deciding_organization_id: SETCIdentifier
    outcome: AdjudicationOutcome
    rationale: str
    decided_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.rationale.strip():
            raise ValueError("adjudicative determination requires rationale")
        if not self.evidence_references:
            raise ValueError("adjudicative determination requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("determination evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AdjudicativeRemedy:
    remedy_id: SETCIdentifier
    determination_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    remedy: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.issuing_organization_id == self.responsible_organization_id:
            raise ValueError("adjudicative remedy requires distinct issuer and responsible organization")
        if not self.remedy.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("adjudicative remedy requires remedy, authority, and evidence")
