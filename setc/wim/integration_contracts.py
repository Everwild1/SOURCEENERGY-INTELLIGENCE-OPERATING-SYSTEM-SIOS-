"""WIM cross-domain contracts with explicit authority boundaries."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping

from setc.integration_contracts import IntegrationContract, IntegrationEnvelope, ContractDirection


WIM_ORGANIZATION_PROJECTION_V1 = IntegrationContract(
    name="wim.organization-projection",
    version="1.0",
    approved_consumers=frozenset({"WIM"}),
)

WIM_SOURCE_BLOCK_RESEARCH_V1 = IntegrationContract(
    name="wim.source-block-research-reference",
    version="1.0",
    approved_consumers=frozenset({"WIM", "SOURCE_BLOCK"}),
)

WIM_SOURCE_COIN_REQUEST_V1 = IntegrationContract(
    name="wim.source-coin-economic-request",
    version="1.0",
    approved_consumers=frozenset({"WIM", "SOURCE_COIN_GATEWAY"}),
)


@dataclass(frozen=True, slots=True)
class SourceCoinEconomicRequest:
    request_reference: str
    transaction_reference: str
    request_type: str
    payload: Mapping[str, Any]

    def __post_init__(self) -> None:
        for field_name in ("request_reference", "transaction_reference", "request_type"):
            if not getattr(self, field_name).strip():
                raise ValueError(f"{field_name} is required")

    def to_envelope(self) -> IntegrationEnvelope:
        return IntegrationEnvelope.build(
            WIM_SOURCE_COIN_REQUEST_V1,
            consumer="SOURCE_COIN_GATEWAY",
            direction=ContractDirection.REQUEST,
            payload={
                "request_reference": self.request_reference,
                "transaction_reference": self.transaction_reference,
                "request_type": self.request_type,
                "payload": dict(self.payload),
                "authority_boundary": "request_only_no_ledger_mutation",
            },
        )
