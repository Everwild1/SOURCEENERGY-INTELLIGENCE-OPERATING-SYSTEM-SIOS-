"""WF-DB-005 governed Fashion supply-chain and global-trade contracts."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID
from .service import FashionContractError

class SupplyChainStage(StrEnum):
    MATERIAL_SOURCE="material_source"; SUPPLIER_QUALIFICATION="supplier_qualification"; PRODUCTION="production"; QUALITY="quality"; INVENTORY="inventory"; LOGISTICS="logistics"; CUSTOMS="customs"; DISTRIBUTION="distribution"; MARKET_ACCESS="market_access"; TRADE="trade"

@dataclass(frozen=True, slots=True)
class FashionSupplyChainBinding:
    production_order_id: UUID
    supply_node_id: UUID
    material_id: UUID|None=None
    production_batch_id: UUID|None=None
    distribution_program_id: UUID|None=None
    rgl_shipment_id: UUID|None=None
    wim_opportunity_id: UUID|None=None
    wim_transaction_id: UUID|None=None
    evidence_reference: str|None=None
    def validate(self)->None:
        if not self.evidence_reference: raise FashionContractError("Supply-chain binding requires evidence reference")
        if self.wim_transaction_id and not self.wim_opportunity_id: raise FashionContractError("Trade transaction binding requires market opportunity context")
        if self.rgl_shipment_id and not self.production_batch_id: raise FashionContractError("Shipment binding requires a production batch")

@dataclass(frozen=True, slots=True)
class TradeBoundaryDecision:
    market_access_ready: bool
    logistics_ready: bool
    compliance_ready: bool
    relationship_integrity: bool
    settlement_final: bool=False
    def validate(self)->None:
        if self.settlement_final: raise FashionContractError("Fashion supply-chain orchestration cannot assert settlement finality")

class SupplyChainAuthorityReader(Protocol):
    def fashion_object_exists(self,resource:str,object_id:UUID)->bool: ...
    def gsc_supply_node_verified(self,supply_node_id:UUID)->bool: ...
    def gsc_distribution_program_exists(self,program_id:UUID)->bool: ...
    def rgl_shipment_exists(self,shipment_id:UUID)->bool: ...
    def rgl_customs_clearance_satisfied(self,shipment_id:UUID)->bool: ...
    def wim_opportunity_exists(self,opportunity_id:UUID)->bool: ...
    def wim_transaction_exists(self,transaction_id:UUID)->bool: ...
    def wim_trade_compliance_satisfied(self,transaction_id:UUID)->bool: ...
    def evidence_verified(self,evidence_reference:str)->bool: ...
    def production_order_uses_supply_node(self,order_id:UUID,node_id:UUID)->bool: ...
    def production_batch_belongs_to_order(self,batch_id:UUID,order_id:UUID)->bool: ...
    def production_batch_origin_matches_node(self,batch_id:UUID,node_id:UUID)->bool: ...
    def production_batch_shipment_matches(self,batch_id:UUID,shipment_id:UUID)->bool: ...
    def distribution_program_origin_matches_node(self,program_id:UUID,node_id:UUID)->bool: ...
    def shipment_origin_matches_supply_node_facility(self,shipment_id:UUID,node_id:UUID)->bool: ...
    def transaction_belongs_to_opportunity(self,transaction_id:UUID,opportunity_id:UUID)->bool: ...
    def shipment_corridor_matches_transaction(self,shipment_id:UUID,transaction_id:UUID)->bool: ...

class FashionSupplyChainValidator:
    def __init__(self,authorities:SupplyChainAuthorityReader)->None: self._authorities=authorities
    def validate_binding(self,b:FashionSupplyChainBinding)->None:
        b.validate(); a=self._authorities
        if not a.fashion_object_exists("production_orders",b.production_order_id): raise FashionContractError("Fashion production order was not found")
        if b.material_id and not a.fashion_object_exists("materials",b.material_id): raise FashionContractError("Fashion material was not found")
        if b.production_batch_id and not a.fashion_object_exists("production_batches",b.production_batch_id): raise FashionContractError("Fashion production batch was not found")
        if not a.gsc_supply_node_verified(b.supply_node_id): raise FashionContractError("Supply node must be verified by GSC authority")
        if not a.production_order_uses_supply_node(b.production_order_id,b.supply_node_id): raise FashionContractError("Production order is not governed by the referenced supply node")
        if b.production_batch_id:
            if not a.production_batch_belongs_to_order(b.production_batch_id,b.production_order_id): raise FashionContractError("Production batch does not belong to production order")
            if not a.production_batch_origin_matches_node(b.production_batch_id,b.supply_node_id): raise FashionContractError("Production batch origin does not match supply node")
        if b.distribution_program_id:
            if not a.gsc_distribution_program_exists(b.distribution_program_id): raise FashionContractError("GSC distribution program was not found")
            if not a.distribution_program_origin_matches_node(b.distribution_program_id,b.supply_node_id): raise FashionContractError("Distribution program origin does not match supply node")
        if b.rgl_shipment_id:
            if not a.rgl_shipment_exists(b.rgl_shipment_id): raise FashionContractError("RGL shipment was not found")
            if not a.production_batch_shipment_matches(b.production_batch_id,b.rgl_shipment_id): raise FashionContractError("Production batch is not linked to referenced shipment")
            if not a.shipment_origin_matches_supply_node_facility(b.rgl_shipment_id,b.supply_node_id): raise FashionContractError("Shipment origin facility does not match supply node")
        if b.wim_opportunity_id and not a.wim_opportunity_exists(b.wim_opportunity_id): raise FashionContractError("WIM opportunity was not found")
        if b.wim_transaction_id:
            if not a.wim_transaction_exists(b.wim_transaction_id): raise FashionContractError("WIM transaction was not found")
            if not a.transaction_belongs_to_opportunity(b.wim_transaction_id,b.wim_opportunity_id): raise FashionContractError("WIM transaction does not belong to referenced opportunity")
            if b.rgl_shipment_id and not a.shipment_corridor_matches_transaction(b.rgl_shipment_id,b.wim_transaction_id): raise FashionContractError("Shipment corridor does not match WIM transaction corridor")
        if not a.evidence_verified(b.evidence_reference or ""): raise FashionContractError("Supply-chain evidence must be verified")

    def trade_readiness(self,b:FashionSupplyChainBinding)->TradeBoundaryDecision:
        self.validate_binding(b); a=self._authorities
        logistics_ready=bool(b.rgl_shipment_id)
        compliance_ready=False
        if b.rgl_shipment_id: compliance_ready=a.rgl_customs_clearance_satisfied(b.rgl_shipment_id)
        if b.wim_transaction_id: compliance_ready=compliance_ready and a.wim_trade_compliance_satisfied(b.wim_transaction_id)
        decision=TradeBoundaryDecision(bool(b.wim_opportunity_id),logistics_ready,compliance_ready,True)
        decision.validate(); return decision
