"""Institutional asset and capital stewardship primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from setc.core import SETCIdentifier


class AssetType(StrEnum):
    CASH_EQUIVALENT = "CASH_EQUIVALENT"
    SECURITY = "SECURITY"
    REAL_ASSET = "REAL_ASSET"
    INTELLECTUAL_PROPERTY = "INTELLECTUAL_PROPERTY"
    EQUIPMENT = "EQUIPMENT"
    CONTRACTUAL_RIGHT = "CONTRACTUAL_RIGHT"
    OTHER = "OTHER"


class ValuationStatus(StrEnum):
    REPORTED = "REPORTED"
    REVIEWED = "REVIEWED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"
    SUPERSEDED = "SUPERSEDED"


class AssetTransferState(StrEnum):
    PROPOSED = "PROPOSED"
    APPROVED = "APPROVED"
    EXECUTED = "EXECUTED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


@dataclass(frozen=True, slots=True)
class AssetRecord:
    asset_id: SETCIdentifier
    organization_id: SETCIdentifier
    asset_reference: str
    asset_type: AssetType
    claimed_owner_organization_id: SETCIdentifier
    custodian_organization_id: SETCIdentifier | None = None
    restricted: bool = False
    restriction_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.asset_reference.strip():
            raise ValueError("asset_reference cannot be blank")
        if self.restriction_reference is not None and not self.restriction_reference.strip():
            raise ValueError("restriction_reference cannot be blank")
        if self.restricted and self.restriction_reference is None:
            raise ValueError("restricted assets require a restriction reference")


@dataclass(frozen=True, slots=True)
class StewardshipAuthority:
    authority_id: SETCIdentifier
    organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("stewardship authority requires scope, authority, and evidence")


@dataclass(frozen=True, slots=True)
class CapitalAllocation:
    allocation_id: SETCIdentifier
    source_organization_id: SETCIdentifier
    beneficiary_organization_id: SETCIdentifier
    purpose: str
    amount: Decimal
    currency: str
    authority_id: SETCIdentifier
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.amount <= 0:
            raise ValueError("capital allocation amount must be positive")
        if not self.purpose.strip() or not self.currency.strip() or not self.evidence_reference.strip():
            raise ValueError("capital allocation requires purpose, currency, and evidence")


@dataclass(frozen=True, slots=True)
class AssetValuationObservation:
    valuation_id: SETCIdentifier
    asset_id: SETCIdentifier
    value: Decimal
    currency: str
    as_of: datetime
    status: ValuationStatus = ValuationStatus.REPORTED
    valuing_organization_id: SETCIdentifier | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.value < 0:
            raise ValueError("asset valuation cannot be negative")
        if not self.currency.strip():
            raise ValueError("valuation currency cannot be blank")
        if self.status == ValuationStatus.VERIFIED and not self.evidence_references:
            raise ValueError("verified valuation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("valuation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AssetEncumbrance:
    encumbrance_id: SETCIdentifier
    asset_id: SETCIdentifier
    beneficiary_organization_id: SETCIdentifier
    encumbrance_type: str
    evidence_reference: str
    effective_from: datetime | None = None
    effective_to: datetime | None = None

    def __post_init__(self) -> None:
        if not self.encumbrance_type.strip() or not self.evidence_reference.strip():
            raise ValueError("asset encumbrance requires type and evidence")
        if self.effective_from and self.effective_to and self.effective_to <= self.effective_from:
            raise ValueError("encumbrance end must follow start")


@dataclass(frozen=True, slots=True)
class AssetTransfer:
    transfer_id: SETCIdentifier
    asset_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    authority_id: SETCIdentifier
    state: AssetTransferState = AssetTransferState.PROPOSED
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("asset transfer requires distinct organizations")
        if self.state in {AssetTransferState.APPROVED, AssetTransferState.EXECUTED} and (
            self.evidence_reference is None or not self.evidence_reference.strip()
        ):
            raise ValueError("approved or executed transfer requires evidence")


@dataclass(frozen=True, slots=True)
class AssetVerification:
    verification_id: SETCIdentifier
    asset_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    claim_type: str
    verified: bool
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.verifier_organization_id:
            raise ValueError("asset verification requires an independent verifier")
        if not self.claim_type.strip() or not self.evidence_reference.strip():
            raise ValueError("asset verification requires claim type and evidence")
