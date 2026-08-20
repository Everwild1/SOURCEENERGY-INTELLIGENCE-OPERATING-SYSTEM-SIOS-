"""Core WIM Exchange value objects and bounded domain contracts."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
import re

_SETCOID = re.compile(r"^SETC-OID-[0-9a-f]{32}$")
_WIM_CLUSTER = re.compile(r"^WIM-[TL][0-9]{2}$")


class EconomicClusterScope(StrEnum):
    TRADED = "traded"
    LOCAL = "local"


class VerificationStatus(StrEnum):
    UNVERIFIED = "unverified"
    PENDING = "pending"
    VERIFIED = "verified"
    RESTRICTED = "restricted"
    SUSPENDED = "suspended"


class OrganizationEconomicStatus(StrEnum):
    INACTIVE = "inactive"
    ACTIVE = "active"
    RESTRICTED = "restricted"
    SUSPENDED = "suspended"


class OpportunityType(StrEnum):
    BUY = "buy"
    SELL = "sell"
    SOURCE = "source"
    SUPPLY = "supply"
    PROCURE = "procure"
    INVEST = "invest"
    PARTNER = "partner"
    EXPORT = "export"
    IMPORT = "import"
    COMMERCIALIZE = "commercialize"


@dataclass(frozen=True, slots=True)
class SetcOrganizationId:
    value: str

    def __post_init__(self) -> None:
        normalized = self.value.strip()
        if not _SETCOID.fullmatch(normalized):
            raise ValueError("SETC organization ID must match SETC-OID-<32 lowercase hex>")
        object.__setattr__(self, "value", normalized)


@dataclass(frozen=True, slots=True)
class EconomicCluster:
    canonical_code: str
    source_cluster_number: int
    name: str
    scope: EconomicClusterScope
    source_url: str
    source_verified: bool = False

    def __post_init__(self) -> None:
        code = self.canonical_code.strip()
        name = self.name.strip()
        source_url = self.source_url.strip()
        if not _WIM_CLUSTER.fullmatch(code):
            raise ValueError("invalid WIM cluster canonical code")
        expected_prefix = "WIM-T" if self.scope is EconomicClusterScope.TRADED else "WIM-L"
        if not code.startswith(expected_prefix):
            raise ValueError("cluster code/scope mismatch")
        if self.source_cluster_number < 1:
            raise ValueError("source cluster number must be positive")
        if not name or not source_url:
            raise ValueError("cluster name and source URL are required")
        object.__setattr__(self, "canonical_code", code)
        object.__setattr__(self, "name", name)
        object.__setattr__(self, "source_url", source_url)

    def require_canonical_use(self) -> None:
        if not self.source_verified:
            raise ValueError("pending taxonomy cannot be used as canonical production taxonomy")


@dataclass(frozen=True, slots=True)
class OrganizationBinding:
    setc_organization_id: SetcOrganizationId
    legal_name: str
    verification_status: VerificationStatus = VerificationStatus.UNVERIFIED
    economic_status: OrganizationEconomicStatus = OrganizationEconomicStatus.INACTIVE

    def __post_init__(self) -> None:
        legal_name = self.legal_name.strip()
        if not legal_name:
            raise ValueError("legal name is required")
        object.__setattr__(self, "legal_name", legal_name)

    def require_commercial_activity(self) -> None:
        if self.verification_status is not VerificationStatus.VERIFIED:
            raise ValueError("organization must be verified for commercial activity")
        if self.economic_status is not OrganizationEconomicStatus.ACTIVE:
            raise ValueError("organization must be economically active")


@dataclass(frozen=True, slots=True)
class SourceCoinRequestReference:
    """A correlation reference only; never proof of Source Coin settlement."""

    value: str

    def __post_init__(self) -> None:
        normalized = self.value.strip()
        if not normalized:
            raise ValueError("Source Coin request reference is required")
        object.__setattr__(self, "value", normalized)

    @property
    def confers_settlement_finality(self) -> bool:
        return False
