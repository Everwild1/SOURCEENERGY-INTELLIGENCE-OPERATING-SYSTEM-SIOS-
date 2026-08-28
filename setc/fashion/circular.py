"""WF-DB-008 append-only circular product lifecycle governance."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID
from .service import FashionContractError

class CircularStage(StrEnum):
    DESIGN="design"; PRODUCE="produce"; SELL="sell"; USE="use"; AUTHENTICATE="authenticate"
    REPAIR="repair"; RESELL="resell"; RECOVER="recover"; RECYCLE="recycle"; REMANUFACTURE="remanufacture"; REINTRODUCE="reintroduce"

@dataclass(frozen=True, slots=True)
class CircularEventBinding:
    product_instance_id: UUID
    stage: CircularStage
    actor_organization_oid: str
    evidence_reference: str
    wim_transaction_id: UUID | None = None
    rgl_delivery_evidence_id: UUID | None = None
    seae_revenue_event_id: UUID | None = None
    seae_royalty_allocation_id: UUID | None = None

    def validate(self) -> None:
        if not self.actor_organization_oid.strip() or not self.evidence_reference.strip():
            raise FashionContractError("Circular event requires actor and evidence")
        if self.stage == CircularStage.RESELL and not self.wim_transaction_id:
            raise FashionContractError("Resale requires authoritative transaction evidence")

class CircularAuthorityReader(Protocol):
    def product_instance_exists(self, object_id: UUID) -> bool: ...
    def organization_active(self, oid: str) -> bool: ...
    def evidence_verified(self, reference: str) -> bool: ...
    def wim_transaction_exists(self, object_id: UUID) -> bool: ...
    def delivery_evidence_verified(self, object_id: UUID) -> bool: ...
    def revenue_event_exists(self, object_id: UUID) -> bool: ...
    def royalty_allocation_exists(self, object_id: UUID) -> bool: ...

class FashionCircularValidator:
    def __init__(self, authorities: CircularAuthorityReader) -> None: self._a=authorities
    def validate_event(self, event: CircularEventBinding) -> None:
        event.validate()
        if not self._a.product_instance_exists(event.product_instance_id): raise FashionContractError("Product instance not found")
        if not self._a.organization_active(event.actor_organization_oid): raise FashionContractError("Actor organization not active")
        if not self._a.evidence_verified(event.evidence_reference): raise FashionContractError("Lifecycle evidence not verified")
        if event.wim_transaction_id and not self._a.wim_transaction_exists(event.wim_transaction_id): raise FashionContractError("WIM transaction not found")
        if event.rgl_delivery_evidence_id and not self._a.delivery_evidence_verified(event.rgl_delivery_evidence_id): raise FashionContractError("Delivery evidence not verified")
        if event.seae_revenue_event_id and not self._a.revenue_event_exists(event.seae_revenue_event_id): raise FashionContractError("Revenue event not found")
        if event.seae_royalty_allocation_id and not self._a.royalty_allocation_exists(event.seae_royalty_allocation_id): raise FashionContractError("Royalty allocation not found")

    @staticmethod
    def assert_append_only(operation: str) -> None:
        if operation.lower() not in {"insert", "select"}: raise FashionContractError("Circular lifecycle history is append-only")

    @staticmethod
    def assert_no_authority_escalation(payload: dict[str, object]) -> None:
        forbidden={"legal_owner","ownership_transferred","payment_final","settlement_final","royalty_paid_final","authenticity_authority","recycling_certified"}
        if forbidden.intersection(payload): raise FashionContractError("Fashion lifecycle cannot assert external ownership, payment, settlement, royalty, authenticity, or certification authority")
