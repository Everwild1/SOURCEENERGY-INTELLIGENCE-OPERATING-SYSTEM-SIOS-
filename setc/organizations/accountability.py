"""Institutional accountability and transparency primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class DisclosureClassification(StrEnum):
    PUBLIC = "PUBLIC"
    INTERNAL = "INTERNAL"
    CONFIDENTIAL = "CONFIDENTIAL"
    RESTRICTED = "RESTRICTED"


class AttestationStatus(StrEnum):
    ASSERTED = "ASSERTED"
    REVIEWED = "REVIEWED"
    WITHDRAWN = "WITHDRAWN"
    SUPERSEDED = "SUPERSEDED"


class AccountabilityFindingState(StrEnum):
    OPEN = "OPEN"
    REMEDIATING = "REMEDIATING"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class AccountabilityAssignment:
    assignment_id: SETCIdentifier
    organization_id: SETCIdentifier
    accountable_organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    effective_from: datetime | None = None
    effective_to: datetime | None = None

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.authority_reference.strip():
            raise ValueError("accountability assignment requires scope and authority")
        if self.effective_from and self.effective_to and self.effective_to <= self.effective_from:
            raise ValueError("accountability assignment end must follow start")


@dataclass(frozen=True, slots=True)
class TransparencyObligation:
    obligation_id: SETCIdentifier
    organization_id: SETCIdentifier
    obligation_reference: str
    authority_reference: str
    required_disclosure: str

    def __post_init__(self) -> None:
        if not self.obligation_reference.strip() or not self.authority_reference.strip() or not self.required_disclosure.strip():
            raise ValueError("transparency obligation requires reference, authority, and disclosure requirement")


@dataclass(frozen=True, slots=True)
class DisclosureRecord:
    disclosure_id: SETCIdentifier
    organization_id: SETCIdentifier
    subject_reference: str
    classification: DisclosureClassification
    disclosed_at: datetime
    evidence_reference: str
    recipient_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("disclosure record requires subject and evidence")
        if self.recipient_reference is not None and not self.recipient_reference.strip():
            raise ValueError("recipient_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class InstitutionalAttestation:
    attestation_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    attesting_organization_id: SETCIdentifier
    claim: str
    status: AttestationStatus = AttestationStatus.ASSERTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.claim.strip():
            raise ValueError("attestation claim cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("attestation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ConflictOfInterestDeclaration:
    declaration_id: SETCIdentifier
    declaring_organization_id: SETCIdentifier
    subject_reference: str
    conflict_description: str
    declared_at: datetime
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.conflict_description.strip() or not self.evidence_reference.strip():
            raise ValueError("conflict declaration requires subject, description, and evidence")


@dataclass(frozen=True, slots=True)
class AccountabilityFinding:
    finding_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    finding: str
    state: AccountabilityFindingState = AccountabilityFindingState.OPEN
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.finding.strip():
            raise ValueError("accountability finding cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class CorrectiveCommitment:
    commitment_id: SETCIdentifier
    finding_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    due_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("corrective commitment action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
