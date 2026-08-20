"""Products, services and supplier capability contracts for WIM Exchange."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum

from .domain import OrganizationBinding, VerificationStatus


class OfferingType(StrEnum):
    PRODUCT = "product"
    SERVICE = "service"
    CAPABILITY = "capability"


class AvailabilityStatus(StrEnum):
    DRAFT = "draft"
    AVAILABLE = "available"
    LIMITED = "limited"
    UNAVAILABLE = "unavailable"
    DISCONTINUED = "discontinued"


@dataclass(frozen=True, slots=True)
class PriceReference:
    amount: Decimal
    currency: str

    def __post_init__(self) -> None:
        if self.amount < 0:
            raise ValueError("price amount cannot be negative")
        if len(self.currency.strip()) != 3 or not self.currency.strip().isalpha():
            raise ValueError("currency must be a three-letter code")
        object.__setattr__(self, "currency", self.currency.strip().upper())

    @property
    def confers_payment_or_settlement(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class SupplierOffering:
    supplier: OrganizationBinding
    name: str
    offering_type: OfferingType
    subcluster_code: str
    availability: AvailabilityStatus = AvailabilityStatus.DRAFT
    verification_status: VerificationStatus = VerificationStatus.UNVERIFIED
    evidence_reference: str = ""
    price: PriceReference | None = None

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("offering name is required")
        if not self.subcluster_code.strip():
            raise ValueError("verified subcluster binding is required")

    def require_publishable(self) -> None:
        self.supplier.require_commercial_activity()
        if self.verification_status is not VerificationStatus.VERIFIED:
            raise ValueError("offering must be verified before publication")
        if self.availability not in {AvailabilityStatus.AVAILABLE, AvailabilityStatus.LIMITED}:
            raise ValueError("offering must be available or limited to publish")
        if not self.evidence_reference.strip():
            raise ValueError("verified offering requires evidence/provenance")

    @property
    def creates_settlement_finality(self) -> bool:
        return False
