"""Procurement and market-access primitives for the SETC Organizations side chain."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ProcurementReadinessState(StrEnum):
    NOT_ASSESSED = "NOT_ASSESSED"
    IN_REVIEW = "IN_REVIEW"
    READY = "READY"
    CONDITIONALLY_READY = "CONDITIONALLY_READY"
    NOT_READY = "NOT_READY"
    SUSPENDED = "SUSPENDED"
    EXPIRED = "EXPIRED"


class OpportunityState(StrEnum):
    DRAFT = "DRAFT"
    OPEN = "OPEN"
    CLOSED = "CLOSED"
    EVALUATING = "EVALUATING"
    AWARDED = "AWARDED"
    CANCELLED = "CANCELLED"


class BidState(StrEnum):
    DRAFT = "DRAFT"
    SUBMITTED = "SUBMITTED"
    WITHDRAWN = "WITHDRAWN"
    DISQUALIFIED = "DISQUALIFIED"
    SHORTLISTED = "SHORTLISTED"
    UNSUCCESSFUL = "UNSUCCESSFUL"
    AWARDED = "AWARDED"


@dataclass(frozen=True, slots=True)
class ProcurementReadinessProfile:
    profile_id: SETCIdentifier
    organization_id: SETCIdentifier
    state: ProcurementReadinessState = ProcurementReadinessState.NOT_ASSESSED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    capital_readiness_certification_id: SETCIdentifier | None = None

    def __post_init__(self) -> None:
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ProcurementOpportunity:
    opportunity_id: SETCIdentifier
    buyer_organization_id: SETCIdentifier
    title: str
    state: OpportunityState = OpportunityState.DRAFT
    opens_at: datetime | None = None
    closes_at: datetime | None = None
    eligibility_requirements: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.title.strip():
            raise ValueError("opportunity title cannot be blank")
        if self.opens_at and self.closes_at and self.closes_at <= self.opens_at:
            raise ValueError("opportunity close must follow open")
        if any(not value.strip() for value in self.eligibility_requirements):
            raise ValueError("eligibility requirements cannot contain blanks")


@dataclass(frozen=True, slots=True)
class SupplierQualification:
    qualification_id: SETCIdentifier
    opportunity_id: SETCIdentifier
    supplier_organization_id: SETCIdentifier
    qualified: bool
    evidence_reference: str
    reviewed_by_organization_id: SETCIdentifier

    def __post_init__(self) -> None:
        if self.supplier_organization_id == self.reviewed_by_organization_id:
            raise ValueError("supplier cannot self-qualify")
        if not self.evidence_reference.strip():
            raise ValueError("qualification requires evidence")


@dataclass(frozen=True, slots=True)
class ProcurementBid:
    bid_id: SETCIdentifier
    opportunity_id: SETCIdentifier
    supplier_organization_id: SETCIdentifier
    state: BidState = BidState.DRAFT
    proposal_reference: str | None = None
    compliance_evidence: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.proposal_reference is not None and not self.proposal_reference.strip():
            raise ValueError("proposal_reference cannot be blank")
        if any(not ref.strip() for ref in self.compliance_evidence):
            raise ValueError("compliance evidence cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ProcurementAward:
    award_id: SETCIdentifier
    opportunity_id: SETCIdentifier
    bid_id: SETCIdentifier
    buyer_organization_id: SETCIdentifier
    supplier_organization_id: SETCIdentifier
    evidence_reference: str
    awarded_at: datetime

    def __post_init__(self) -> None:
        if self.buyer_organization_id == self.supplier_organization_id:
            raise ValueError("buyer and supplier must be distinct")
        if not self.evidence_reference.strip():
            raise ValueError("award requires evidence")


@dataclass(frozen=True, slots=True)
class MarketAccessReferral:
    referral_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    referring_organization_id: SETCIdentifier
    target_market: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.referring_organization_id:
            raise ValueError("market-access referral requires independent referring organization")
        if not self.target_market.strip():
            raise ValueError("target_market cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ContractPerformanceRecord:
    performance_id: SETCIdentifier
    award_id: SETCIdentifier
    metric: str
    value: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.metric.strip() or not self.value.strip() or not self.evidence_reference.strip():
            raise ValueError("contract performance record requires metric, value, and evidence")
