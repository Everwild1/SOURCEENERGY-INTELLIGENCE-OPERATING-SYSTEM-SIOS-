"""Institutional identity and authority-resolution primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class IdentityStatus(StrEnum):
    ASSERTED = "ASSERTED"
    REVIEWED = "REVIEWED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"
    RETIRED = "RETIRED"


class DelegationStatus(StrEnum):
    PROPOSED = "PROPOSED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"
    EXPIRED = "EXPIRED"


@dataclass(frozen=True, slots=True)
class InstitutionalIdentity:
    identity_id: SETCIdentifier
    organization_id: SETCIdentifier
    canonical_name: str
    jurisdiction_reference: str | None = None
    status: IdentityStatus = IdentityStatus.ASSERTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.canonical_name.strip():
            raise ValueError("canonical_name cannot be blank")
        if self.jurisdiction_reference is not None and not self.jurisdiction_reference.strip():
            raise ValueError("jurisdiction_reference cannot be blank")
        if self.status == IdentityStatus.VERIFIED and not self.evidence_references:
            raise ValueError("verified institutional identity requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("identity evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class IdentityAlias:
    alias_id: SETCIdentifier
    identity_id: SETCIdentifier
    alias: str
    source_reference: str
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.alias.strip() or not self.source_reference.strip():
            raise ValueError("identity alias requires alias and source reference")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("identity alias validity end must follow start")


@dataclass(frozen=True, slots=True)
class RepresentativeCapacity:
    capacity_id: SETCIdentifier
    represented_organization_id: SETCIdentifier
    representative_organization_id: SETCIdentifier
    role: str
    authority_reference: str
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.represented_organization_id == self.representative_organization_id:
            raise ValueError("representative capacity requires distinct organizations")
        if not self.role.strip() or not self.authority_reference.strip():
            raise ValueError("representative capacity requires role and authority")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("representative capacity end must follow start")


@dataclass(frozen=True, slots=True)
class DelegatedAuthority:
    delegation_id: SETCIdentifier
    delegating_organization_id: SETCIdentifier
    delegate_organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    evidence_reference: str
    status: DelegationStatus = DelegationStatus.PROPOSED
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.delegating_organization_id == self.delegate_organization_id:
            raise ValueError("delegated authority requires distinct organizations")
        if not self.scope.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("delegated authority requires scope, authority, and evidence")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("delegation validity end must follow start")


@dataclass(frozen=True, slots=True)
class AuthorityRevocation:
    revocation_id: SETCIdentifier
    delegation_id: SETCIdentifier
    revoked_by_organization_id: SETCIdentifier
    rationale: str
    evidence_reference: str
    revoked_at: datetime

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("authority revocation requires rationale and evidence")


@dataclass(frozen=True, slots=True)
class IdentityResolutionRecord:
    resolution_id: SETCIdentifier
    subject_reference: str
    resolved_identity_id: SETCIdentifier
    resolver_organization_id: SETCIdentifier
    resolution_basis: str
    confidence: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.resolution_basis.strip() or not self.confidence.strip():
            raise ValueError("identity resolution requires subject, basis, and confidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("resolution evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AuthorityAssertion:
    assertion_id: SETCIdentifier
    organization_id: SETCIdentifier
    authority_scope: str
    claim: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    verified: bool = False

    def __post_init__(self) -> None:
        if not self.authority_scope.strip() or not self.claim.strip():
            raise ValueError("authority assertion requires scope and claim")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("authority assertion evidence references cannot contain blanks")
        if self.verified and not self.evidence_references:
            raise ValueError("verified authority assertion requires evidence")
