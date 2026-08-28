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
    market_access_request_id: UUID | None = None
    wim_opportunity_id: UUID | None = None
    procurement_opportunity_id: int | None = None
    wim_transaction_id: UUID | None = None

    def validate(self) -> None:
        if not self.evidence_reference.strip():
            raise FashionContractError("Market access requires evidence")
        if self.wim_transaction_id and not self.wim_opportunity_id:
            raise FashionContractError("WIM transaction requires opportunity context")


@dataclass(frozen=True, slots=True)
class MarketReadiness:
    entity_ready: bool
    product_ready: bool
    procurement_ready: bool
    trade_ready: bool
    evidence_ready: bool
    opportunity_ready: bool
    logistics_ready: bool

    @property
    def market_ready(self) -> bool:
        return all((self.entity_ready, self.product_ready, self.procurement_ready, self.trade_ready, self.evidence_ready))


class MarketAccessAuthorityReader(Protocol):
    def fashion_object_exists(self, resource: str, object_id: UUID) -> bool: ...
    def organization_active(self, organization_id: UUID) -> bool: ...
    def wim_product_verified(self, product_id: UUID) -> bool: ...
    def procurement_readiness_satisfied(self, profile_id: UUID, organization_id: UUID) -> bool: ...
    def trade_readiness_satisfied(self, profile_id: UUID, organization_id: UUID) -> bool: ...
    def evidence_verified(self, reference: str) -> bool: ...
    def market_access_request_exists(self, request_id: UUID) -> bool: ...
    def wim_opportunity_exists(self, opportunity_id: UUID) -> bool: ...
    def procurement_opportunity_exists(self, opportunity_id: int) -> bool: ...
    def wim_transaction_exists(self, transaction_id: UUID) -> bool: ...
    def logistics_ready(self, transaction_id: UUID) -> bool: ...


class FashionMarketAccessValidator:
    def __init__(self, authorities: MarketAccessAuthorityReader) -> None:
        self._authorities = authorities

    def evaluate(self, binding: MarketAccessBinding) -> MarketReadiness:
        binding.validate()
        entity_ready = self._authorities.organization_active(binding.organization_id)
        product_ready = (
            self._authorities.fashion_object_exists("brands", binding.brand_id)
            and self._authorities.fashion_object_exists("product_models", binding.product_model_id)
            and self._authorities.wim_product_verified(binding.wim_product_service_id)
        )
        procurement_ready = self._authorities.procurement_readiness_satisfied(
            binding.procurement_readiness_profile_id, binding.organization_id
        )
        trade_ready = self._authorities.trade_readiness_satisfied(
            binding.trade_readiness_profile_id, binding.organization_id
        )
        evidence_ready = self._authorities.evidence_verified(binding.evidence_reference)
        if binding.market_access_request_id and not self._authorities.market_access_request_exists(binding.market_access_request_id):
            raise FashionContractError("CRUDS market-access request was not found")
        opportunity_ready = bool(binding.wim_opportunity_id or binding.procurement_opportunity_id)
        if binding.wim_opportunity_id and not self._authorities.wim_opportunity_exists(binding.wim_opportunity_id):
            raise FashionContractError("WIM opportunity was not found")
        if binding.procurement_opportunity_id and not self._authorities.procurement_opportunity_exists(binding.procurement_opportunity_id):
            raise FashionContractError("Procurement opportunity was not found")
        logistics_ready = False
        if binding.wim_transaction_id:
            if not self._authorities.wim_transaction_exists(binding.wim_transaction_id):
                raise FashionContractError("WIM transaction was not found")
            logistics_ready = self._authorities.logistics_ready(binding.wim_transaction_id)
        return MarketReadiness(
            entity_ready=entity_ready,
            product_ready=product_ready,
            procurement_ready=procurement_ready,
            trade_ready=trade_ready,
            evidence_ready=evidence_ready,
            opportunity_ready=opportunity_ready,
            logistics_ready=logistics_ready,
        )

    @staticmethod
    def assert_no_settlement_authority(payload: dict[str, object]) -> None:
        forbidden = {"settlement_final", "payment_final", "source_coin_final", "custody_final"}
        if forbidden.intersection(payload):
            raise FashionContractError("Fashion market access cannot assert settlement, payment, Source Coin, or custody finality")
