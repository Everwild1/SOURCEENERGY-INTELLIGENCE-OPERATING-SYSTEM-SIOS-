"""Core Ecology Block value objects and authority-safe cross-domain references."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
import re
from typing import Optional

_SETCOID = re.compile(r"^SETC-OID-[0-9a-f]{32}$")


class EcologyDomain(StrEnum):
    SETC = "setc"
    SOURCE_BLOCK = "source_block"
    WIM = "wim"
    CRUDS = "cruds"
    HEI = "hei"
    GSC = "gsc"
    RGL = "rgl"
    CAPITALIZATION = "capitalization"
    SOURCE_COIN = "source_coin"
    EXTERNAL_AUTHORITY = "external_authority"


class AuthorityPosture(StrEnum):
    AUTHORITATIVE_PROJECTION = "authoritative_projection"
    REFERENCE_ONLY = "reference_only"
    REQUEST_ONLY = "request_only"
    DERIVED_PROJECTION = "derived_projection"


@dataclass(frozen=True, slots=True)
class SetcOrganizationId:
    """Canonical institutional identity reference; Ecology never mints these IDs."""

    value: str

    def __post_init__(self) -> None:
        normalized = self.value.strip()
        if not _SETCOID.fullmatch(normalized):
            raise ValueError("SETC organization ID must match SETC-OID-<32 lowercase hex>")
        object.__setattr__(self, "value", normalized)


@dataclass(frozen=True, slots=True)
class EvidenceReference:
    authority: str
    reference: str

    def __post_init__(self) -> None:
        authority = self.authority.strip()
        reference = self.reference.strip()
        if not authority or not reference:
            raise ValueError("evidence authority and reference are required")
        object.__setattr__(self, "authority", authority)
        object.__setattr__(self, "reference", reference)

    @property
    def confers_verification(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class EcologyObjectReference:
    """Typed pointer to a source-domain object; never a copy of source authority."""

    domain: EcologyDomain
    object_type: str
    object_id: str
    source_authority: str
    posture: AuthorityPosture = AuthorityPosture.REFERENCE_ONLY
    organization_id: Optional[SetcOrganizationId] = None
    evidence: Optional[EvidenceReference] = None

    def __post_init__(self) -> None:
        object_type = self.object_type.strip()
        object_id = self.object_id.strip()
        source_authority = self.source_authority.strip()
        if not object_type or not object_id or not source_authority:
            raise ValueError("object type, object ID and source authority are required")
        if self.posture is AuthorityPosture.AUTHORITATIVE_PROJECTION and self.domain is not EcologyDomain.SETC:
            raise ValueError("source-domain objects cannot become authoritative through an Ecology reference")
        object.__setattr__(self, "object_type", object_type)
        object.__setattr__(self, "object_id", object_id)
        object.__setattr__(self, "source_authority", source_authority)

    @property
    def transfers_source_authority(self) -> bool:
        return False

    @property
    def confers_settlement_finality(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class EcologyCorrelation:
    correlation_id: str
    causation_id: Optional[str] = None
    idempotency_key: Optional[str] = None

    def __post_init__(self) -> None:
        correlation_id = self.correlation_id.strip()
        if not correlation_id:
            raise ValueError("correlation ID is required")
        object.__setattr__(self, "correlation_id", correlation_id)
        for field_name in ("causation_id", "idempotency_key"):
            value = getattr(self, field_name)
            if value is not None:
                normalized = value.strip()
                if not normalized:
                    raise ValueError(f"{field_name} cannot be blank")
                object.__setattr__(self, field_name, normalized)
