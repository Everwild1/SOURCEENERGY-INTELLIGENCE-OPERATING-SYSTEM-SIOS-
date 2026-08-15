"""Cross-cutting verification, credential, and evidence controls governed by SETC-119."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class EvidenceClassification(StrEnum):
    PUBLIC = "PUBLIC"
    INTERNAL = "INTERNAL"
    CONFIDENTIAL = "CONFIDENTIAL"
    RESTRICTED = "RESTRICTED"


class VerificationStatus(StrEnum):
    ASSERTED = "ASSERTED"
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"


class CredentialStatus(StrEnum):
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"


@dataclass(frozen=True, slots=True)
class EvidenceRecord:
    evidence_id: SETCIdentifier
    subject_reference: str
    source_reference: str
    classification: EvidenceClassification = EvidenceClassification.INTERNAL
    collected_at: datetime | None = None
    hash_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.source_reference.strip():
            raise ValueError("evidence requires subject and source references")
        if self.hash_reference is not None and not self.hash_reference.strip():
            raise ValueError("hash_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class VerificationAuthority:
    authority_id: SETCIdentifier
    organization_id: SETCIdentifier
    scope: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.evidence_reference.strip():
            raise ValueError("verification authority requires scope and evidence")


@dataclass(frozen=True, slots=True)
class VerificationRecord:
    verification_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    authority_id: SETCIdentifier
    claim_type: str
    status: VerificationStatus = VerificationStatus.ASSERTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.verifier_organization_id:
            raise ValueError("organization cannot self-verify")
        if not self.claim_type.strip():
            raise ValueError("claim_type cannot be blank")
        if self.status == VerificationStatus.VERIFIED and not self.evidence_references:
            raise ValueError("verified claims require evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("evidence references cannot contain blanks")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("verification validity end must follow start")


@dataclass(frozen=True, slots=True)
class Credential:
    credential_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    issuer_organization_id: SETCIdentifier
    credential_type: str
    status: CredentialStatus = CredentialStatus.ACTIVE
    issued_at: datetime | None = None
    expires_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.issuer_organization_id:
            raise ValueError("credential issuer must be independent from subject")
        if not self.credential_type.strip():
            raise ValueError("credential_type cannot be blank")
        if self.issued_at and self.expires_at and self.expires_at <= self.issued_at:
            raise ValueError("credential expiry must follow issuance")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class AccreditationMapping:
    mapping_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    accrediting_organization_id: SETCIdentifier
    credential_id: SETCIdentifier
    accreditation_reference: str

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.accrediting_organization_id:
            raise ValueError("organization cannot self-accredit")
        if not self.accreditation_reference.strip():
            raise ValueError("accreditation_reference cannot be blank")
