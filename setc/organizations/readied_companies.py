"""SETC-121 Foundation-to-Incubator company readiness gates.

This module models readiness evidence. It does not establish legal status,
government eligibility, financial viability, or authority to bid or contract.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum

from setc.core import SETCIdentifier


class DefinitionState(StrEnum):
    NOT_STARTED = "NOT_STARTED"
    DRAFT_DEFINED = "DRAFT_DEFINED"
    VERIFIED = "VERIFIED"
    FAILED = "FAILED"
    EXPIRED = "EXPIRED"


class PeopleFitState(StrEnum):
    PENDING = "PENDING"
    IN_REVIEW = "IN_REVIEW"
    CONFIRMED = "CONFIRMED"
    FAILED = "FAILED"
    EXPIRED = "EXPIRED"


class CompanyReadinessGate(StrEnum):
    FOUNDATION_REMEDIATION = "FOUNDATION_REMEDIATION"
    PEOPLE_FIT_PENDING = "PEOPLE_FIT_PENDING"
    READY_FOR_OPPORTUNITY_GATE = "READY_FOR_OPPORTUNITY_GATE"


class ProfitabilityMode(StrEnum):
    COMMERCIAL = "COMMERCIAL"
    MISSION_SUSTAINABILITY = "MISSION_SUSTAINABILITY"


class OpportunityAuthorityState(StrEnum):
    WITHHELD = "WITHHELD"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    SUPERSEDED = "SUPERSEDED"


@dataclass(frozen=True, slots=True)
class ReadinessDefinition:
    """One Purpose, Product, or Profitability definition and its evidence."""

    statement: str
    state: DefinitionState = DefinitionState.NOT_STARTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    owner_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.statement.strip():
            raise ValueError("readiness statement cannot be blank")
        if any(not value.strip() for value in self.evidence_references):
            raise ValueError("evidence references cannot contain blanks")
        if self.owner_reference is not None and not self.owner_reference.strip():
            raise ValueError("owner_reference cannot be blank")
        if self.state is DefinitionState.VERIFIED:
            if not self.evidence_references:
                raise ValueError("verified definitions require evidence")
            if self.owner_reference is None:
                raise ValueError("verified definitions require an owner")


@dataclass(frozen=True, slots=True)
class PeopleFitRecord:
    """Human and organizational team-fit evidence for one company."""

    state: PeopleFitState = PeopleFitState.PENDING
    role_blueprint_reference: str | None = None
    primary_team_references: tuple[str, ...] = field(default_factory=tuple)
    alternate_team_references: tuple[str, ...] = field(default_factory=tuple)
    consent_evidence_references: tuple[str, ...] = field(default_factory=tuple)
    availability_evidence_references: tuple[str, ...] = field(default_factory=tuple)
    credential_evidence_references: tuple[str, ...] = field(default_factory=tuple)
    conflict_review_reference: str | None = None
    workshare_review_reference: str | None = None
    reviewer_reference: str | None = None

    def __post_init__(self) -> None:
        collections = (
            self.primary_team_references,
            self.alternate_team_references,
            self.consent_evidence_references,
            self.availability_evidence_references,
            self.credential_evidence_references,
        )
        if any(not value.strip() for values in collections for value in values):
            raise ValueError("people-fit references cannot contain blanks")
        optional = (
            self.role_blueprint_reference,
            self.conflict_review_reference,
            self.workshare_review_reference,
            self.reviewer_reference,
        )
        if any(value is not None and not value.strip() for value in optional):
            raise ValueError("people-fit references cannot be blank")

        if self.state is PeopleFitState.CONFIRMED:
            required = (
                self.role_blueprint_reference,
                self.primary_team_references,
                self.alternate_team_references,
                self.consent_evidence_references,
                self.availability_evidence_references,
                self.credential_evidence_references,
                self.conflict_review_reference,
                self.workshare_review_reference,
                self.reviewer_reference,
            )
            if not all(required):
                raise ValueError(
                    "confirmed people fit requires blueprint, primary and alternate "
                    "coverage, consent, availability, credentials, conflict, "
                    "workshare, and reviewer evidence"
                )


@dataclass(frozen=True, slots=True)
class CompanyReadinessProfile:
    """SETC-121 company profile at the Foundation/Incubator block."""

    profile_id: SETCIdentifier
    organization_id: SETCIdentifier
    purpose: ReadinessDefinition
    product: ReadinessDefinition
    profitability: ReadinessDefinition
    people_fit: PeopleFitRecord = field(default_factory=PeopleFitRecord)
    profitability_mode: ProfitabilityMode = ProfitabilityMode.COMMERCIAL
    registry_reference: str | None = None

    def __post_init__(self) -> None:
        if self.registry_reference is not None and not self.registry_reference.strip():
            raise ValueError("registry_reference cannot be blank")

    @property
    def readiness_gate(self) -> CompanyReadinessGate:
        definitions = (self.purpose, self.product, self.profitability)
        if (
            all(item.state is DefinitionState.VERIFIED for item in definitions)
            and self.people_fit.state is PeopleFitState.CONFIRMED
        ):
            return CompanyReadinessGate.READY_FOR_OPPORTUNITY_GATE

        defined_states = {DefinitionState.DRAFT_DEFINED, DefinitionState.VERIFIED}
        if (
            all(item.state in defined_states for item in definitions)
            and self.people_fit.state in {PeopleFitState.PENDING, PeopleFitState.IN_REVIEW}
        ):
            return CompanyReadinessGate.PEOPLE_FIT_PENDING

        return CompanyReadinessGate.FOUNDATION_REMEDIATION

    @property
    def opportunity_authority(self) -> OpportunityAuthorityState:
        """Readiness never creates bid or contracting authority."""

        return OpportunityAuthorityState.WITHHELD

    def may_enter_opportunity_review(self) -> bool:
        return self.readiness_gate is CompanyReadinessGate.READY_FOR_OPPORTUNITY_GATE
