"""Interoperability and external institutional-exchange primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ExchangeDirection(StrEnum):
    INBOUND = "INBOUND"
    OUTBOUND = "OUTBOUND"
    BIDIRECTIONAL = "BIDIRECTIONAL"


class ExchangeStatus(StrEnum):
    DRAFT = "DRAFT"
    AUTHORIZED = "AUTHORIZED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"
    EXPIRED = "EXPIRED"


class ImportTrustStatus(StrEnum):
    IMPORTED = "IMPORTED"
    SOURCE_ATTESTED = "SOURCE_ATTESTED"
    SETC_REVIEWED = "SETC_REVIEWED"
    SETC_VERIFIED = "SETC_VERIFIED"
    REJECTED = "REJECTED"


@dataclass(frozen=True, slots=True)
class ExternalInstitutionMapping:
    mapping_id: SETCIdentifier
    organization_id: SETCIdentifier
    external_system: str
    external_identifier: str
    source_authority_reference: str

    def __post_init__(self) -> None:
        for value, label in (
            (self.external_system, "external_system"),
            (self.external_identifier, "external_identifier"),
            (self.source_authority_reference, "source_authority_reference"),
        ):
            if not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class ExchangeSchema:
    schema_id: SETCIdentifier
    name: str
    version: str
    schema_reference: str

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip() or not self.schema_reference.strip():
            raise ValueError("exchange schema requires name, version, and reference")


@dataclass(frozen=True, slots=True)
class DataSharingAuthorization:
    authorization_id: SETCIdentifier
    source_organization_id: SETCIdentifier
    counterparty_organization_id: SETCIdentifier
    direction: ExchangeDirection
    scope: str
    evidence_reference: str
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.source_organization_id == self.counterparty_organization_id:
            raise ValueError("data-sharing authorization requires distinct organizations")
        if not self.scope.strip() or not self.evidence_reference.strip():
            raise ValueError("authorization requires scope and evidence")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("authorization validity end must follow start")


@dataclass(frozen=True, slots=True)
class InstitutionalExchange:
    exchange_id: SETCIdentifier
    authorization_id: SETCIdentifier
    schema_id: SETCIdentifier
    direction: ExchangeDirection
    status: ExchangeStatus = ExchangeStatus.DRAFT
    source_system: str = ""
    destination_system: str = ""

    def __post_init__(self) -> None:
        if not self.source_system.strip() or not self.destination_system.strip():
            raise ValueError("exchange requires source and destination systems")
        if self.source_system == self.destination_system:
            raise ValueError("exchange source and destination systems must differ")


@dataclass(frozen=True, slots=True)
class EvidencePackage:
    package_id: SETCIdentifier
    exchange_id: SETCIdentifier
    source_authority_reference: str
    record_references: tuple[str, ...] = field(default_factory=tuple)
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    trust_status: ImportTrustStatus = ImportTrustStatus.IMPORTED
    received_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.source_authority_reference.strip():
            raise ValueError("source authority reference cannot be blank")
        if any(not ref.strip() for ref in self.record_references):
            raise ValueError("record references cannot contain blanks")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("evidence references cannot contain blanks")
        if self.trust_status == ImportTrustStatus.SETC_VERIFIED and not self.evidence_references:
            raise ValueError("SETC-verified imported packages require SETC evidence")


@dataclass(frozen=True, slots=True)
class SynchronizationRecord:
    synchronization_id: SETCIdentifier
    exchange_id: SETCIdentifier
    external_cursor: str
    synchronized_at: datetime
    successful: bool
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.external_cursor.strip():
            raise ValueError("external_cursor cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
