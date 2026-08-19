"""SETC / Source Block integration boundary for Source Coin (SC-E10).

Integration inputs are requests and evidence. They are never ledger mutation
commands. Economic execution remains inside the Source Coin ledger boundary.
"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional
from uuid import UUID

from setc.core import SETCIdentifier


class EconomicRequestType(str, Enum):
    SETTLEMENT = "SETTLEMENT"
    REWARD = "REWARD"


class IntegrationDecision(str, Enum):
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    DUPLICATE = "DUPLICATE"


@dataclass(frozen=True)
class ChainAnchorReference:
    network_ref: str
    anchor_ref: str
    proof_ref: Optional[str] = None

    def __post_init__(self) -> None:
        if not self.network_ref.strip() or not self.anchor_ref.strip():
            raise ValueError("chain anchor network_ref and anchor_ref are required")


@dataclass(frozen=True)
class SourceBlockEconomicRequest:
    request_id: UUID
    source_block_id: str
    organization_id: SETCIdentifier
    request_type: EconomicRequestType
    provenance_ref: str
    correlation_id: str
    causation_id: str
    idempotency_key: str
    obligation_ref: Optional[str] = None
    contribution_ref: Optional[str] = None
    chain_anchor: Optional[ChainAnchorReference] = None

    def __post_init__(self) -> None:
        required = {
            "source_block_id": self.source_block_id,
            "provenance_ref": self.provenance_ref,
            "correlation_id": self.correlation_id,
            "causation_id": self.causation_id,
            "idempotency_key": self.idempotency_key,
        }
        for name, value in required.items():
            if not value.strip():
                raise ValueError(f"{name} is required")
        if self.request_type is EconomicRequestType.SETTLEMENT and not self.obligation_ref:
            raise ValueError("settlement requests require obligation_ref")
        if self.request_type is EconomicRequestType.REWARD and not self.contribution_ref:
            raise ValueError("reward requests require contribution_ref")

    @property
    def may_mutate_ledger(self) -> bool:
        """Source Blocks never receive direct economic mutation authority."""
        return False


@dataclass(frozen=True)
class InstitutionalGatewayContext:
    principal_ref: str
    organization_id: SETCIdentifier
    authorization_ref: str
    policy_decision_ref: str

    def __post_init__(self) -> None:
        for value in (
            self.principal_ref,
            self.authorization_ref,
            self.policy_decision_ref,
        ):
            if not value.strip():
                raise ValueError("gateway authorization fields are required")


def validate_source_block_request(request: SourceBlockEconomicRequest) -> IntegrationDecision:
    """Validate integration shape without creating an economic side effect."""
    if request.may_mutate_ledger:
        return IntegrationDecision.REJECTED
    return IntegrationDecision.ACCEPTED
