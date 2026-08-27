"""Core CRUDS Universe value objects and authority-safe contracts."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from uuid import UUID


class CreatorArchetype(StrEnum):
    ARTIST = "artist"
    THINKER = "thinker"
    ADVENTURER = "adventurer"
    MAKER = "maker"
    PRODUCER = "producer"
    DREAMER = "dreamer"


class PublicationStatus(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class VerificationStatus(StrEnum):
    UNVERIFIED = "unverified"
    PENDING = "pending"
    VERIFIED = "verified"
    DISPUTED = "disputed"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class CreatorProfile:
    id: UUID
    display_name: str
    identity_reference: str

    def __post_init__(self) -> None:
        if not self.display_name.strip():
            raise ValueError("display name is required")
        if not self.identity_reference.strip():
            raise ValueError("authoritative identity reference is required")


@dataclass(frozen=True, slots=True)
class CreativeWork:
    id: UUID
    creator_id: UUID
    title: str
    publication_status: PublicationStatus = PublicationStatus.DRAFT

    def __post_init__(self) -> None:
        if not self.title.strip():
            raise ValueError("work title is required")


@dataclass(frozen=True, slots=True)
class WitnessVerificationReference:
    """Evidence reference only; it does not itself confer legal IP ownership."""

    value: str
    status: VerificationStatus = VerificationStatus.UNVERIFIED

    def __post_init__(self) -> None:
        if not self.value.strip():
            raise ValueError("witness verification reference is required")

    @property
    def confers_legal_ip_ownership(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class WimMarketAccessReference:
    """Cross-context correlation only; WIM retains market workflow authority."""

    value: str

    def __post_init__(self) -> None:
        if not self.value.strip():
            raise ValueError("WIM market access reference is required")


@dataclass(frozen=True, slots=True)
class SourceCoinSettlementReference:
    """Correlation only; never proof of Source Coin settlement finality."""

    value: str

    def __post_init__(self) -> None:
        if not self.value.strip():
            raise ValueError("Source Coin settlement reference is required")

    @property
    def confers_settlement_finality(self) -> bool:
        return False
