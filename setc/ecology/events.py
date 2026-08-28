"""ECO-E03 cross-domain event contracts.

Events coordinate bounded domains; they never replace the source system's authority.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import StrEnum
from typing import Mapping, Optional, Sequence

from .domain import EcologyCorrelation, EcologyDomain, EcologyObjectReference, SetcOrganizationId


class EcologyEventName(StrEnum):
    EVIDENCE_REGISTERED = "ecology.evidence.registered"
    RESEARCH_REFERENCED = "ecology.research.referenced"
    IP_REFERENCED = "ecology.ip.referenced"
    COMMERCIALIZATION_ADVANCED = "ecology.commercialization.advanced"
    MARKET_OPPORTUNITY_REFERENCED = "ecology.market_opportunity.referenced"
    CAPITAL_READINESS_REFERENCED = "ecology.capital_readiness.referenced"
    TRANSACTION_REFERENCED = "ecology.transaction.referenced"
    SETTLEMENT_REFERENCED = "ecology.settlement.referenced"
    IMPACT_RECORDED = "ecology.impact.recorded"
    REGENERATIVE_ALLOCATION_PROPOSED = "ecology.regenerative_allocation.proposed"
    REINVESTMENT_REFERENCED = "ecology.reinvestment.referenced"


@dataclass(frozen=True, slots=True)
class EcologyEventEnvelope:
    event_id: str
    event_name: EcologyEventName
    contract_version: str
    producer: EcologyDomain
    source_authority: str
    correlation: EcologyCorrelation
    subject: EcologyObjectReference
    references: Sequence[EcologyObjectReference] = field(default_factory=tuple)
    organization_id: Optional[SetcOrganizationId] = None
    occurred_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    recorded_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    attributes: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for field_name in ("event_id", "contract_version", "source_authority"):
            value = getattr(self, field_name).strip()
            if not value:
                raise ValueError(f"{field_name} is required")
            object.__setattr__(self, field_name, value)
        if self.contract_version != "1.0":
            raise ValueError("unsupported Ecology event contract version")
        if self.occurred_at.tzinfo is None or self.recorded_at.tzinfo is None:
            raise ValueError("event timestamps must be timezone-aware")
        if self.recorded_at < self.occurred_at:
            raise ValueError("recorded_at cannot precede occurred_at")
        if self.subject.domain is not self.producer:
            raise ValueError("producer must match the authoritative domain of the event subject")
        if self.source_authority != self.subject.source_authority:
            raise ValueError("event source authority must match subject source authority")
        if self.event_name is EcologyEventName.SETTLEMENT_REFERENCED and self.producer is EcologyDomain.SOURCE_COIN:
            # Source Coin may report a reference/economic effect, but the Ecology envelope is never finality proof.
            pass

    @property
    def confers_source_authority(self) -> bool:
        return False

    @property
    def confers_settlement_finality(self) -> bool:
        return False

    @property
    def is_replay_safe(self) -> bool:
        return self.correlation.idempotency_key is not None


def require_material_command_idempotency(event: EcologyEventEnvelope) -> None:
    """Fail closed for events that can trigger downstream governed work."""
    material = {
        EcologyEventName.COMMERCIALIZATION_ADVANCED,
        EcologyEventName.CAPITAL_READINESS_REFERENCED,
        EcologyEventName.TRANSACTION_REFERENCED,
        EcologyEventName.SETTLEMENT_REFERENCED,
        EcologyEventName.REGENERATIVE_ALLOCATION_PROPOSED,
        EcologyEventName.REINVESTMENT_REFERENCED,
    }
    if event.event_name in material and not event.is_replay_safe:
        raise ValueError("material Ecology event requires an idempotency key")
