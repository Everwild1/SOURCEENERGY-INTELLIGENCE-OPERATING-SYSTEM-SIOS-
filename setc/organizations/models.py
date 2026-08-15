"""Canonical organization primitives governed by SETC-117/119."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum

from setc.core import SETCIdentifier


class OrganizationType(StrEnum):
    FOUNDATION = "FOUNDATION"
    UNIVERSITY = "UNIVERSITY"
    RESEARCH_INSTITUTION = "RESEARCH_INSTITUTION"
    INCUBATOR = "INCUBATOR"
    ACCELERATOR = "ACCELERATOR"
    ENTREPRENEURSHIP_CENTER = "ENTREPRENEURSHIP_CENTER"
    VENTURE_STUDIO = "VENTURE_STUDIO"
    TECHNOLOGY_TRANSFER_ORGANIZATION = "TECHNOLOGY_TRANSFER_ORGANIZATION"
    DEVELOPMENT_ORGANIZATION = "DEVELOPMENT_ORGANIZATION"
    CAPITAL_PROVIDER = "CAPITAL_PROVIDER"
    ENTERPRISE = "ENTERPRISE"
    GOVERNMENT = "GOVERNMENT"
    NONPROFIT = "NONPROFIT"
    OTHER = "OTHER"


class OrganizationCapability(StrEnum):
    FUNDS = "FUNDS"
    GRANTS = "GRANTS"
    RESEARCHES = "RESEARCHES"
    COMMERCIALIZES = "COMMERCIALIZES"
    INCUBATES = "INCUBATES"
    ACCELERATES = "ACCELERATES"
    FORMS_VENTURES = "FORMS_VENTURES"
    INVESTS = "INVESTS"
    LENDS = "LENDS"
    PROCURES = "PROCURES"
    SUPPLIES = "SUPPLIES"
    VERIFIES = "VERIFIES"
    ACCREDITS = "ACCREDITS"


class VerificationState(StrEnum):
    UNVERIFIED = "UNVERIFIED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    VERIFIED = "VERIFIED"
    ENHANCED_VERIFICATION = "ENHANCED_VERIFICATION"
    ACCREDITED = "ACCREDITED"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"
    ARCHIVED = "ARCHIVED"


@dataclass(slots=True)
class Organization:
    """One canonical institutional identity with many governed capabilities."""

    oid: SETCIdentifier
    legal_name: str
    organization_type: OrganizationType
    verification_state: VerificationState = VerificationState.UNVERIFIED
    capabilities: set[OrganizationCapability] = field(default_factory=set)
    aliases: set[str] = field(default_factory=set)

    def __post_init__(self) -> None:
        self.legal_name = self.legal_name.strip()
        if not self.legal_name:
            raise ValueError("organization legal_name is required")
        self.aliases = {alias.strip() for alias in self.aliases if alias.strip()}
