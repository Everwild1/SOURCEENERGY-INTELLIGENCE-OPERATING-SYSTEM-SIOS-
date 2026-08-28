"""WF-DB-006 governed Fashion market-access orchestration."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID
from .service import FashionContractError

@dataclass(frozen=True, slots=True)
class MarketAccessBinding:
    brand_id: UUID
    product_model_id: UUID
    organization_id: UUID
    wim_product_service_id: UUID
    procurement_readiness_profile_id: UUID
    trade_readiness_profile_id: UUID
    evidence_reference: str
    market_access_request_id: UUID|None=None
    wim_opportunity_id: UUID|None=None
    procurement_opportunity_id: int|None=None
    wim_transaction_id: UUID|None=None
    def validate(self)->None:
        if not self.evidence_reference.strip(): raise FashionContractError("Market access requires evidence")
        if self.wim_transaction_id and not self.wim_opportunity_id: raise FashionContractError("WIM transaction requires opportunity context")

@dataclass(frozen=True, slots=True)
class MarketReadiness:
    entity_ready: bool
    product_ready: bool
    procurement_ready: bool
    trade_ready: bool
    evidence_ready: bool
    opportunity_ready: bool
    logistics_ready: bool
    relationship_integrity: bool
    @property
    def market_ready(self)->bool:
        return all((self.entity_ready,self.product_ready,self.procurement_ready,self.trade_ready,self.evidence_ready,self.relationship_integrity))

class MarketAccessAuthorityReader(Protocol):
    def fashion_object_exists(self,resource:str,object_id:UUID)->bool: ...
    def organization_active(self,organization_id:UUID)->bool: ...
    def wim_product_verified(self,product_id:UUID)->bool: ...
    def procurement_readiness_satisfied(self,profile_id:UUID,organization_id:UUID)->bool: ...
    def trade_readiness_satisfied(self,profile_id:UUID,organization_id:UUID)->bool: ...
    def evidence_verified(self,reference:str)->bool: ...
    def market_access_request_exists(self,request_id:UUID)->bool: ...
    def wim_opportunity_exists(self,opportunity_id:UUID)->bool: ...
    def procurement_opportunity_exists(self,opportunity_id:int)->bool: ...
    def wim_transaction_exists(self,transaction_id:UUID)->bool: ...
    def logistics_ready(self,transaction_id:UUID)->bool: ...
    def brand_owned_by_organization(self,brand_id:UUID,organization_id:UUID)->bool: ...
    def brand_wim_organization_matches(self,brand_id:UUID,organization_id:UUID)->bool: ...
    def product_model_belongs_to_brand(self,product_model_id:UUID,brand_id:UUID)->bool: ...
    def product_model_wim_product_matches(self,product_model_id:UUID,wim_product_id:UUID)->bool: ...
    def wim_product_owned_by_organization(self,wim_product_id:UUID,organization_id:UUID)->bool: ...
    def market_access_request_matches_product(self,request_id:UUID,product_model_id:UUID)->bool: ...
    def market_access_request_matches_opportunity(self,request_id:UUID,opportunity_id:UUID)->bool: ...
    def procurement_opportunity_admissible_for_organization(self,opportunity_id:int,organization_id:UUID)->bool: ...
    def wim_transaction_belongs_to_opportunity(self,transaction_id:UUID,opportunity_id:UUID)->bool: ...
    def wim_transaction_seller_matches_organization(self,transaction_id:UUID,organization_id:UUID)->bool: ...

class FashionMarketAccessValidator:
    def __init__(self,authorities:MarketAccessAuthorityReader)->None: self._a=authorities
    def evaluate(self,b:MarketAccessBinding)->MarketReadiness:
        b.validate(); a=self._a
        entity_ready=a.organization_active(b.organization_id)
        product_ready=(a.fashion_object_exists("brands",b.brand_id) and a.fashion_object_exists("product_models",b.product_model_id) and a.wim_product_verified(b.wim_product_service_id))
        relationship_integrity=True
        if product_ready:
            relationship_integrity=(a.brand_owned_by_organization(b.brand_id,b.organization_id) and a.brand_wim_organization_matches(b.brand_id,b.organization_id) and a.product_model_belongs_to_brand(b.product_model_id,b.brand_id) and a.product_model_wim_product_matches(b.product_model_id,b.wim_product_service_id) and a.wim_product_owned_by_organization(b.wim_product_service_id,b.organization_id))
        procurement_ready=a.procurement_readiness_satisfied(b.procurement_readiness_profile_id,b.organization_id)
        trade_ready=a.trade_readiness_satisfied(b.trade_readiness_profile_id,b.organization_id)
        evidence_ready=a.evidence_verified(b.evidence_reference)
        if b.market_access_request_id:
            if not a.market_access_request_exists(b.market_access_request_id): raise FashionContractError("CRUDS market-access request was not found")
            if not a.market_access_request_matches_product(b.market_access_request_id,b.product_model_id): raise FashionContractError("CRUDS market-access request does not match Fashion product")
            if b.wim_opportunity_id and not a.market_access_request_matches_opportunity(b.market_access_request_id,b.wim_opportunity_id): raise FashionContractError("CRUDS market-access request does not match WIM opportunity")
        opportunity_ready=bool(b.wim_opportunity_id or b.procurement_opportunity_id)
        if b.wim_opportunity_id and not a.wim_opportunity_exists(b.wim_opportunity_id): raise FashionContractError("WIM opportunity was not found")
        if b.procurement_opportunity_id:
            if not a.procurement_opportunity_exists(b.procurement_opportunity_id): raise FashionContractError("Procurement opportunity was not found")
            if not a.procurement_opportunity_admissible_for_organization(b.procurement_opportunity_id,b.organization_id): raise FashionContractError("Procurement opportunity is not admissible for organization")
        logistics_ready=False
        if b.wim_transaction_id:
            if not a.wim_transaction_exists(b.wim_transaction_id): raise FashionContractError("WIM transaction was not found")
            if not a.wim_transaction_belongs_to_opportunity(b.wim_transaction_id,b.wim_opportunity_id): raise FashionContractError("WIM transaction does not belong to referenced opportunity")
            if not a.wim_transaction_seller_matches_organization(b.wim_transaction_id,b.organization_id): raise FashionContractError("WIM transaction seller does not match Fashion enterprise")
            logistics_ready=a.logistics_ready(b.wim_transaction_id)
        return MarketReadiness(entity_ready,product_ready,procurement_ready,trade_ready,evidence_ready,opportunity_ready,logistics_ready,relationship_integrity)

    @staticmethod
    def assert_no_settlement_authority(payload:dict[str,object])->None:
        forbidden={"settlement_final","payment_final","source_coin_final","custody_final"}
        if forbidden.intersection(payload): raise FashionContractError("Fashion market access cannot assert settlement, payment, Source Coin, or custody finality")
