"""Versioned integration envelopes for Capitalization Block exchanges."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from typing import Any, Mapping
from uuid import uuid4

SUPPORTED_VERSIONS = frozenset({"1.0"})


@dataclass(frozen=True, slots=True)
class CapitalizationEnvelope:
    contract_name: str
    contract_version: str
    event_id: str
    correlation_id: str
    causation_id: str | None
    producer: str
    occurred_at: str
    payload: Mapping[str, Any]

    @classmethod
    def build(
        cls,
        *,
        contract_name: str,
        contract_version: str,
        correlation_id: str,
        producer: str,
        payload: Mapping[str, Any],
        causation_id: str | None = None,
    ) -> "CapitalizationEnvelope":
        name = contract_name.strip()
        version = contract_version.strip()
        correlation = correlation_id.strip()
        source = producer.strip()
        if not name or not correlation or not source:
            raise ValueError("name, correlation_id, and producer are required")
        if version not in SUPPORTED_VERSIONS:
            raise ValueError("unsupported capitalization contract version")
        return cls(
            contract_name=name,
            contract_version=version,
            event_id=str(uuid4()),
            correlation_id=correlation,
            causation_id=causation_id.strip() if causation_id else None,
            producer=source,
            occurred_at=datetime.now(UTC).isoformat(),
            payload=dict(payload),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
