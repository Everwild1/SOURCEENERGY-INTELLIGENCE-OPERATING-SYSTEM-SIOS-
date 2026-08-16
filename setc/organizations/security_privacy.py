"""Security, privacy, and data-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class DataClassification(StrEnum):
    PUBLIC = "PUBLIC"
    INTERNAL = "INTERNAL"
    CONFIDENTIAL = "CONFIDENTIAL"
    RESTRICTED = "RESTRICTED"


class LegalBasis(StrEnum):
    CONSENT = "CONSENT"
    CONTRACT = "CONTRACT"
    LEGAL_OBLIGATION = "LEGAL_OBLIGATION"
    LEGITIMATE_INTEREST = "LEGITIMATE_INTEREST"
    PUBLIC_TASK = "PUBLIC_TASK"
    VITAL_INTEREST = "VITAL_INTEREST"


class IncidentState(StrEnum):
    OPEN = "OPEN"
    CONTAINED = "CONTAINED"
    REMEDIATING = "REMEDIATING"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class DataGovernancePolicy:
    policy_id: SETCIdentifier
    organization_id: SETCIdentifier
    name: str
    version: str
    policy_reference: str

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip() or not self.policy_reference.strip():
            raise ValueError("data-governance policy requires name, version, and reference")


@dataclass(frozen=True, slots=True)
class DataAssetControl:
    control_id: SETCIdentifier
    subject_reference: str
    classification: DataClassification
    owner_organization_id: SETCIdentifier
    purpose_restrictions: tuple[str, ...] = field(default_factory=tuple)
    disclosure_restrictions: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.subject_reference.strip():
            raise ValueError("subject_reference cannot be blank")
        if any(not value.strip() for value in self.purpose_restrictions):
            raise ValueError("purpose restrictions cannot contain blanks")
        if any(not value.strip() for value in self.disclosure_restrictions):
            raise ValueError("disclosure restrictions cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ProcessingAuthorization:
    authorization_id: SETCIdentifier
    subject_reference: str
    processing_organization_id: SETCIdentifier
    purpose: str
    legal_basis: LegalBasis
    authority_reference: str
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.purpose.strip() or not self.authority_reference.strip():
            raise ValueError("processing authorization requires subject, purpose, and authority")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("processing authorization end must follow start")


@dataclass(frozen=True, slots=True)
class ConsentRecord:
    consent_id: SETCIdentifier
    subject_reference: str
    granted_to_organization_id: SETCIdentifier
    purpose: str
    evidence_reference: str
    granted_at: datetime
    withdrawn_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.purpose.strip() or not self.evidence_reference.strip():
            raise ValueError("consent record requires subject, purpose, and evidence")
        if self.withdrawn_at is not None and self.withdrawn_at < self.granted_at:
            raise ValueError("consent withdrawal cannot precede grant")


@dataclass(frozen=True, slots=True)
class RetentionRule:
    retention_id: SETCIdentifier
    subject_reference: str
    retention_basis: str
    retain_until: datetime | None = None
    deletion_required: bool = False

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.retention_basis.strip():
            raise ValueError("retention rule requires subject and basis")


@dataclass(frozen=True, slots=True)
class PrivacyEvent:
    event_id: SETCIdentifier
    subject_reference: str
    event_type: str
    occurred_at: datetime
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.event_type.strip():
            raise ValueError("privacy event requires subject and type")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class SecurityIncident:
    incident_id: SETCIdentifier
    organization_id: SETCIdentifier
    incident_type: str
    state: IncidentState = IncidentState.OPEN
    detected_at: datetime | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.incident_type.strip():
            raise ValueError("incident_type cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("incident evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AccessDecision:
    decision_id: SETCIdentifier
    subject_reference: str
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    purpose: str
    approved: bool
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("access approval requires independent approving organization")
        if not self.subject_reference.strip() or not self.purpose.strip() or not self.evidence_reference.strip():
            raise ValueError("access decision requires subject, purpose, and evidence")
