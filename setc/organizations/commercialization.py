"""Research, IP, and technology-commercialization primitives governed by SETC-115."""

from dataclasses import dataclass
from enum import StrEnum

from setc.core import SETCIdentifier


class IPRightType(StrEnum):
    PATENT = "PATENT"
    COPYRIGHT = "COPYRIGHT"
    TRADE_SECRET = "TRADE_SECRET"
    KNOW_HOW = "KNOW_HOW"
    DATA_RIGHT = "DATA_RIGHT"
    OTHER = "OTHER"


class CommercializationState(StrEnum):
    DISCLOSED = "DISCLOSED"
    UNDER_REVIEW = "UNDER_REVIEW"
    PROOF_OF_CONCEPT = "PROOF_OF_CONCEPT"
    MARKET_VALIDATION = "MARKET_VALIDATION"
    LICENSING = "LICENSING"
    SPINOUT_PREPARATION = "SPINOUT_PREPARATION"
    COMMERCIALIZED = "COMMERCIALIZED"
    SUSPENDED = "SUSPENDED"
    CLOSED = "CLOSED"


class RightsInstrumentType(StrEnum):
    ASSIGNMENT = "ASSIGNMENT"
    LICENSE = "LICENSE"
    OPTION = "OPTION"
    EVALUATION_RIGHT = "EVALUATION_RIGHT"


@dataclass(frozen=True, slots=True)
class ResearchAssetReference:
    research_reference: str
    source_organization_id: SETCIdentifier
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.research_reference.strip():
            raise ValueError("research_reference cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class InventionDisclosure:
    disclosure_id: SETCIdentifier
    research_reference: str
    disclosing_organization_id: SETCIdentifier
    title: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.research_reference.strip() or not self.title.strip():
            raise ValueError("research reference and title are required")


@dataclass(frozen=True, slots=True)
class IPAssetReference:
    ip_reference: str
    right_type: IPRightType
    claimed_owner_organization_id: SETCIdentifier | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.ip_reference.strip():
            raise ValueError("ip_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class TechnologyTransferAuthority:
    authority_id: SETCIdentifier
    organization_id: SETCIdentifier
    scope: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.evidence_reference.strip():
            raise ValueError("technology-transfer authority requires scope and evidence")


@dataclass(frozen=True, slots=True)
class RightsInstrument:
    instrument_id: SETCIdentifier
    ip_reference: str
    instrument_type: RightsInstrumentType
    grantor_organization_id: SETCIdentifier
    grantee_organization_id: SETCIdentifier
    authority_id: SETCIdentifier
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.grantor_organization_id == self.grantee_organization_id:
            raise ValueError("rights instrument requires distinct grantor and grantee")
        if not self.ip_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("rights instrument requires IP and evidence references")


@dataclass(frozen=True, slots=True)
class CommercializationOpportunity:
    opportunity_id: SETCIdentifier
    research_reference: str
    managing_organization_id: SETCIdentifier
    state: CommercializationState = CommercializationState.DISCLOSED
    venture_id: SETCIdentifier | None = None
    ip_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.research_reference.strip():
            raise ValueError("research_reference cannot be blank")
        if self.ip_reference is not None and not self.ip_reference.strip():
            raise ValueError("ip_reference cannot be blank")
