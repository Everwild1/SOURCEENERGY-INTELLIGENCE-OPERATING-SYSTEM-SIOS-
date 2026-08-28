"""WF-DB-005 governed Fashion supply-chain and global-trade contracts."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID

from .service import FashionContractError


class SupplyChainStage(StrEnum):
    MATERIAL_SOURCE = "material_source"
    SUPPLIER_QUALIFICATION = "supplier_qualification"
    PRODUCTION = "production"
    QUALITY = "quality"
    INVENTORY = "inventory"
    LOGISTICS = "logistics"
    CUSTOMS = "customs"
    DISTRIBUTION = "distribution"
    MARKET_ACCESS = "market_access"
    TRADE = "trade"


@dataclass(frozen=True, slots=True)
class FashionSupplyChainBinding:
    production_order_id: UUID
    supply_node_id: UUID
    material_id: UUID | None = None
    production_batch_id: UUID | None = None
    distribution_program_id: UUID | None = None
    rgl_shipment_id: UUID | None = None
    wim_opportunity_id: UUID | None = None
    wim_transaction_id: UUID | None = None
    evidence_reference: str | None = None

    def validate(self) -> None:
        if not self.evidence_reference:
            raise FashionContractError("Supply-chain binding requires evidence reference")
        if self.wim_transaction_id and not self.wim_opportunity_id:
            raise FashionContractError("Trade transaction binding requires market opportunity context")
        if self.rgl_shipment_id and not self.production_batch_id:
            raise FashionContractError("Shipment binding requires a production batch")


@dataclass(frozen=True, slots=True)
class TradeBoundaryDecision:
    market_access_ready: bool
    logistics_ready: bool
    compliance_ready: bool
    settlement_final: bool = False

    def validate(self) -> None:
        if self.settlement_final:
            raise FashionContractError("Fashion supply-chain orchestration cannot assert settlement finality")


class SupplyChainAuthorityReader(Protocol):
    def fashion_object_exists(self, resource: str, object_id: UUID) -> bool: ...
    def gsc_supply_node_verified(self, supply_node_id: UUID) -> bool: ...
    def gsc_distribution_program_exists(self, program_id: UUID) -> bool: ...
    def rgl_shipment_exists(self, shipment_id: UUID) -> bool: ...
    def rgl_customs_clearance_satisfied(self, shipment_id: UUID) -> bool: ...
    def wim_opportunity_exists(self, opportunity_id: UUID) -> bool: ...
    def wim_transaction_exists(self, transaction_id: UUID) -> bool: ...
    def wim_trade_compliance_satisfied(self, transaction_id: UUID) -> bool: ...
    def evidence_verified(self, evidence_reference: str) -> bool: ...


class FashionSupplyChainValidator:
    def __init__(self, authorities: SupplyChainAuthorityReader) -> None:
        self._authorities = authorities

    def validate_binding(self, binding: FashionSupplyChainBinding) -> None:
        binding.validate()
        if not self._authorities.fashion_object_exists("production_orders", binding.production_order_id):
            raise FashionContractError("Fashion production order was not found")
        if binding.material_id and not self._authorities.fashion_object_exists("materials", binding.material_id):
            raise FashionContractError("Fashion material was not found")
        if binding.production_batch_id and not self._authorities.fashion_object_exists("production_batches", binding.production_batch_id):
            raise FashionContractError("Fashion production batch was not found")
        if not self._authorities.gsc_supply_node_verified(binding.supply_node_id):
            raise FashionContractError("Supply node must be verified by GSC authority")
        if binding.distribution_program_id and not self._authorities.gsc_distribution_program_exists(binding.distribution_program_id):
            raise FashionContractError("GSC distribution program was not found")
        if binding.rgl_shipment_id and not self._authorities.rgl_shipment_exists(binding.rgl_shipment_id):
            raise FashionContractError("RGL shipment was not found")
        if binding.wim_opportunity_id and not self._authorities.wim_opportunity_exists(binding.wim_opportunity_id):
            raise FashionContractError("WIM opportunity was not found")
        if binding.wim_transaction_id and not self._authorities.wim_transaction_exists(binding.wim_transaction_id):
            raise FashionContractError("WIM transaction was not found")
        if not self._authorities.evidence_verified(binding.evidence_reference or ""):
            raise FashionContractError("Supply-chain evidence must be verified")

    def trade_readiness(self, binding: FashionSupplyChainBinding) -> TradeBoundaryDecision:
        self.validate_binding(binding)
        logistics_ready = bool(binding.rgl_shipment_id)
        compliance_ready = False
        if binding.rgl_shipment_id:
            compliance_ready = self._authorities.rgl_customs_clearance_satisfied(binding.rgl_shipment_id)
        if binding.wim_transaction_id:
            compliance_ready = compliance_ready and self._authorities.wim_trade_compliance_satisfied(binding.wim_transaction_id)
        decision = TradeBoundaryDecision(
            market_access_ready=bool(binding.wim_opportunity_id),
            logistics_ready=logistics_ready,
            compliance_ready=compliance_ready,
        )
        decision.validate()
        return decision
