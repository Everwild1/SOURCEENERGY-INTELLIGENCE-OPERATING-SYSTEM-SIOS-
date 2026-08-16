"""Institutional records and document-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class RecordClassification(StrEnum):
    PUBLIC = "PUBLIC"
    INTERNAL = "INTERNAL"
    CONFIDENTIAL = "CONFIDENTIAL"
    RESTRICTED = "RESTRICTED"


class RecordStatus(StrEnum):
    DRAFT = "DRAFT"
    CURRENT = "CURRENT"
    SUPERSEDED = "SUPERSEDED"
    ARCHIVED = "ARCHIVED"
    DISPOSED = "DISPOSED"


class AuthenticityStatus(StrEnum):
    ASSERTED = "ASSERTED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"


@dataclass(frozen=True, slots=True)
class InstitutionalRecord:
    record_id: SETCIdentifier
    organization_id: SETCIdentifier
    record_reference: str
    title: str
    classification: RecordClassification
    custodian_organization_id: SETCIdentifier
    status: RecordStatus = RecordStatus.DRAFT
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.record_reference.strip() or not self.title.strip():
            raise ValueError("institutional record requires reference and title")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("record evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RecordVersion:
    version_id: SETCIdentifier
    record_id: SETCIdentifier
    version: str
    content_reference: str
    created_at: datetime
    supersedes_version_id: SETCIdentifier | None = None

    def __post_init__(self) -> None:
        if not self.version.strip() or not self.content_reference.strip():
            raise ValueError("record version requires version and content reference")
        if self.supersedes_version_id == self.version_id:
            raise ValueError("record version cannot supersede itself")


@dataclass(frozen=True, slots=True)
class RetentionSchedule:
    schedule_id: SETCIdentifier
    organization_id: SETCIdentifier
    record_class_reference: str
    retention_basis: str
    retention_period_days: int | None = None

    def __post_init__(self) -> None:
        if not self.record_class_reference.strip() or not self.retention_basis.strip():
            raise ValueError("retention schedule requires record class and basis")
        if self.retention_period_days is not None and self.retention_period_days < 0:
            raise ValueError("retention period cannot be negative")


@dataclass(frozen=True, slots=True)
class LegalHold:
    hold_id: SETCIdentifier
    record_id: SETCIdentifier
    authority_reference: str
    reason: str
    imposed_at: datetime
    released_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.authority_reference.strip() or not self.reason.strip():
            raise ValueError("legal hold requires authority and reason")
        if self.released_at is not None and self.released_at < self.imposed_at:
            raise ValueError("legal hold release cannot precede imposition")


@dataclass(frozen=True, slots=True)
class RecordDispositionAuthorization:
    disposition_id: SETCIdentifier
    record_id: SETCIdentifier
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    disposition_action: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("record disposition requester cannot self-approve")
        if not self.disposition_action.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("record disposition requires action, authority, and evidence")


@dataclass(frozen=True, slots=True)
class RecordAuthenticityVerification:
    verification_id: SETCIdentifier
    record_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    status: AuthenticityStatus
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.verifier_organization_id:
            raise ValueError("record authenticity verification requires an independent verifier")
        if self.status == AuthenticityStatus.VERIFIED and not self.evidence_references:
            raise ValueError("verified record authenticity requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("authenticity evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class RecordAccessAuthorization:
    authorization_id: SETCIdentifier
    record_id: SETCIdentifier
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    purpose: str
    evidence_reference: str
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("record access requester cannot self-approve")
        if not self.purpose.strip() or not self.evidence_reference.strip():
            raise ValueError("record access authorization requires purpose and evidence")
