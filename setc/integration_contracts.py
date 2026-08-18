"""Bounded, versioned integration contracts for approved SETC ecosystem exchange.

These primitives describe software/data exchange only. They do not confer legal,
regulatory, accreditation, credential, financial, or institutional authority.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import StrEnum
from typing import Any, Mapping


class ContractDirection(StrEnum):
    REQUEST = "REQUEST"
    RESPONSE = "RESPONSE"


SUPPORTED_CONTRACT_VERSIONS = frozenset({"1.0"})


@dataclass(frozen=True, slots=True)
class IntegrationContract:
    name: str
    version: str
    approved_consumers: frozenset[str] = field(default_factory=frozenset)

    def __post_init__(self) -> None:
        name = self.name.strip()
        version = self.version.strip()
        consumers = frozenset(c.strip() for c in self.approved_consumers if c.strip())
        if not name:
            raise ValueError("integration contract name is required")
        if version not in SUPPORTED_CONTRACT_VERSIONS:
            raise ValueError("unsupported integration contract version")
        if not consumers:
            raise ValueError("at least one approved consumer is required")
        object.__setattr__(self, "name", name)
        object.__setattr__(self, "version", version)
        object.__setattr__(self, "approved_consumers", consumers)

    def authorize_consumer(self, consumer: str) -> str:
        normalized = consumer.strip()
        if normalized not in self.approved_consumers:
            raise ValueError("consumer is not approved for this integration contract")
        return normalized


@dataclass(frozen=True, slots=True)
class IntegrationEnvelope:
    contract_name: str
    contract_version: str
    consumer: str
    direction: ContractDirection
    payload: Mapping[str, Any]

    @classmethod
    def build(
        cls,
        contract: IntegrationContract,
        *,
        consumer: str,
        direction: ContractDirection,
        payload: Mapping[str, Any],
    ) -> "IntegrationEnvelope":
        approved_consumer = contract.authorize_consumer(consumer)
        return cls(
            contract_name=contract.name,
            contract_version=contract.version,
            consumer=approved_consumer,
            direction=direction,
            payload=dict(payload),
        )

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["direction"] = self.direction.value
        return data


def validate_envelope(contract: IntegrationContract, envelope: IntegrationEnvelope) -> None:
    if envelope.contract_name != contract.name:
        raise ValueError("integration contract name mismatch")
    if envelope.contract_version != contract.version:
        raise ValueError("integration contract version mismatch")
    contract.authorize_consumer(envelope.consumer)
