"""Venture formation and entrepreneurship-center primitives governed by SETC-114."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class VentureState(StrEnum):
    CONCEPT = "CONCEPT"
    TEAM_FORMING = "TEAM_FORMING"
    PRE_FORMATION = "PRE_FORMATION"
    LEGAL_FORMATION_PENDING = "LEGAL_FORMATION_PENDING"
    LEGALLY_FORMED = "LEGALLY_FORMED"
    ENTERPRISE_ACTIVATION = "ENTERPRISE_ACTIVATION"
    OPERATING = "OPERATING"
    PAUSED = "PAUSED"
    SUSPENDED = "SUSPENDED"
    DISSOLVED = "DISSOLVED"
    ARCHIVED = "ARCHIVED"


class FounderRole(StrEnum):
    FOUNDER = "FOUNDER"
    CO_FOUNDER = "CO_FOUNDER"
    FOUNDING_EXECUTIVE = "FOUNDING_EXECUTIVE"
    ADVISOR = "ADVISOR"


class FounderAuthority(StrEnum):
    NONE = "NONE"
    REPRESENTATIVE = "REPRESENTATIVE"
    SIGNATORY = "SIGNATORY"
    GOVERNANCE = "GOVERNANCE"


@dataclass(frozen=True, slots=True)
class EntrepreneurshipCenterProfile:
    organization_id: SETCIdentifier
    mandate: str
    focus_areas: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.mandate.strip():
            raise ValueError("entrepreneurship-center mandate cannot be blank")
        if any(not value.strip() for value in self.focus_areas):
            raise ValueError("focus areas cannot contain blanks")


@dataclass(frozen=True, slots=True)
class VentureOrigin:
    venture_id: SETCIdentifier
    origin_organization_id: SETCIdentifier
    origin_program_id: SETCIdentifier | None = None
    research_reference: str | None = None
    ip_reference: str | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        for value, label in (
            (self.research_reference, "research_reference"),
            (self.ip_reference, "ip_reference"),
            (self.evidence_reference, "evidence_reference"),
        ):
            if value is not None and not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class FounderRelationship:
    relationship_id: SETCIdentifier
    venture_id: SETCIdentifier
    person_reference: str
    role: FounderRole = FounderRole.FOUNDER
    authority: FounderAuthority = FounderAuthority.NONE
    effective_from: datetime | None = None
    effective_to: datetime | None = None

    def __post_init__(self) -> None:
        if not self.person_reference.strip():
            raise ValueError("person_reference cannot be blank")
        if self.effective_from and self.effective_to and self.effective_to < self.effective_from:
            raise ValueError("founder relationship end cannot precede start")


@dataclass(frozen=True, slots=True)
class LegalEntityFormation:
    formation_id: SETCIdentifier
    venture_id: SETCIdentifier
    legal_entity_organization_id: SETCIdentifier
    jurisdiction: str
    registration_reference: str | None = None
    formed_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.jurisdiction.strip():
            raise ValueError("jurisdiction cannot be blank")
        if self.registration_reference is not None and not self.registration_reference.strip():
            raise ValueError("registration_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class VentureStudioRelationship:
    relationship_id: SETCIdentifier
    venture_id: SETCIdentifier
    studio_organization_id: SETCIdentifier
    scope: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.scope.strip():
            raise ValueError("venture-studio scope cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class EnterpriseActivation:
    activation_id: SETCIdentifier
    venture_id: SETCIdentifier
    enterprise_organization_id: SETCIdentifier
    state: VentureState = VentureState.ENTERPRISE_ACTIVATION
    activated_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class VentureSponsorRelationship:
    relationship_id: SETCIdentifier
    venture_id: SETCIdentifier
    sponsor_organization_id: SETCIdentifier
    sponsorship_type: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.sponsorship_type.strip():
            raise ValueError("sponsorship_type cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
