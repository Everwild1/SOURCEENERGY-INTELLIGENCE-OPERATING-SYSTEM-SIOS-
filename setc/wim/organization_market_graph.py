"""WIM organization-to-market graph contracts.

SETC remains authoritative for institutional organization identity. WIM stores
commercial projections and participation edges only.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from uuid import UUID

from .domain import OrganizationBinding


class MarketRole(StrEnum):
    BUYER = "buyer"
    SELLER = "seller"
    SUPPLIER = "supplier"
    PROCURER = "procurer"
    INVESTOR = "investor"
    PARTNER = "partner"
    EXPORTER = "exporter"
    IMPORTER = "importer"
    COMMERCIALIZER = "commercializer"
    SERVICE_PROVIDER = "service_provider"


class ParticipationStatus(StrEnum):
    INACTIVE = "inactive"
    ACTIVE = "active"
    RESTRICTED = "restricted"
    SUSPENDED = "suspended"


class CorridorRole(StrEnum):
    SHIPPER = "shipper"
    CONSIGNEE = "consignee"
    CARRIER = "carrier"
    BROKER = "broker"
    LOGISTICS_PROVIDER = "logistics_provider"
    BUYER = "buyer"
    SELLER = "seller"
    EXPORTER = "exporter"
    IMPORTER = "importer"


@dataclass(frozen=True, slots=True)
class Market:
    market_id: UUID
    name: str
    market_type: str = "geographic"
    status: str = "active"

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("market name is required")
        if self.status not in {"active", "inactive", "restricted"}:
            raise ValueError("invalid market status")

    def require_participation(self) -> None:
        if self.status != "active":
            raise ValueError("market must be active for participation")


@dataclass(frozen=True, slots=True)
class TradeCorridor:
    corridor_id: UUID
    name: str
    origin_market_id: UUID
    destination_market_id: UUID
    status: str = "proposed"

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("corridor name is required")
        if self.origin_market_id == self.destination_market_id:
            raise ValueError("trade corridor origin and destination must differ")
        if self.status not in {"proposed", "active", "restricted", "inactive"}:
            raise ValueError("invalid corridor status")

    def require_participation(self) -> None:
        if self.status != "active":
            raise ValueError("trade corridor must be active for participation")


@dataclass(frozen=True, slots=True)
class OrganizationMarketMembership:
    organization: OrganizationBinding
    market: Market
    role: MarketRole
    status: ParticipationStatus = ParticipationStatus.INACTIVE
    provenance_reference: str = ""

    def authorize_active_participation(self) -> None:
        self.organization.require_commercial_activity()
        self.market.require_participation()
        if self.status is not ParticipationStatus.ACTIVE:
            raise ValueError("organization-market membership must be active")
        if not self.provenance_reference.strip():
            raise ValueError("market membership provenance is required")


@dataclass(frozen=True, slots=True)
class OrganizationCorridorMembership:
    organization: OrganizationBinding
    corridor: TradeCorridor
    role: CorridorRole
    status: ParticipationStatus = ParticipationStatus.INACTIVE
    provenance_reference: str = ""

    def authorize_active_participation(self) -> None:
        self.organization.require_commercial_activity()
        self.corridor.require_participation()
        if self.status is not ParticipationStatus.ACTIVE:
            raise ValueError("organization-corridor membership must be active")
        if not self.provenance_reference.strip():
            raise ValueError("corridor membership provenance is required")
