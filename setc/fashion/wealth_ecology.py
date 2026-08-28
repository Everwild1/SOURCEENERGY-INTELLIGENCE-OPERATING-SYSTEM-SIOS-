"""WF-DB-009 Fashion Wealth Ecology measurement bindings."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID
from .service import FashionContractError

class WealthCapital(StrEnum):
    CREATIVE="creative"; HUMAN="human"; ENTERPRISE="enterprise"; COMMUNITY="community"
    CULTURAL="cultural"; FINANCIAL="financial"; GENERATIONAL="generational"

class WealthStage(StrEnum):
    ECONOMIC_ACTIVITY="economic_activity"; VALUE_CREATED="value_created"; VALUE_CAPTURED="value_captured"
    VALUE_RETAINED="value_retained"; ASSETS_FORMED="assets_formed"; WEALTH_PRODUCED="wealth_produced"; WEALTH_REINVESTED="wealth_reinvested"

@dataclass(frozen=True, slots=True)
class WealthEcologyBinding:
    organization_id: UUID
    capital_class: WealthCapital
    stage: WealthStage
    evidence_reference: str
    cruds_impact_metric_id: UUID | None = None
    rw_commercial_outcome_id: UUID | None = None
    rw_impact_observation_id: UUID | None = None
    rw_wealth_yield_record_id: UUID | None = None
    rw_investment_asset_id: UUID | None = None
    seae_impact_link_id: UUID | None = None
    seae_revenue_event_id: UUID | None = None

    def validate(self) -> None:
        if not self.evidence_reference.strip(): raise FashionContractError("Wealth Ecology measurement requires evidence")
        if self.stage in {WealthStage.ASSETS_FORMED, WealthStage.WEALTH_PRODUCED, WealthStage.WEALTH_REINVESTED} and not (self.rw_wealth_yield_record_id or self.rw_investment_asset_id):
            raise FashionContractError("Asset/wealth stages require authoritative RW wealth or asset evidence")

class WealthAuthorityReader(Protocol):
    def evidence_verified(self, reference: str) -> bool: ...
    def impact_metric_verified(self, object_id: UUID) -> bool: ...
    def commercial_outcome_verified(self, object_id: UUID, organization_id: UUID) -> bool: ...
    def impact_observation_verified(self, object_id: UUID, organization_id: UUID) -> bool: ...
    def wealth_yield_verified(self, object_id: UUID, organization_id: UUID) -> bool: ...
    def investment_asset_verified(self, object_id: UUID, organization_id: UUID) -> bool: ...
    def seae_impact_link_exists(self, object_id: UUID) -> bool: ...
    def revenue_event_exists(self, object_id: UUID) -> bool: ...

class FashionWealthEcologyValidator:
    def __init__(self, authorities: WealthAuthorityReader) -> None: self._a=authorities
    def validate_measurement(self, b: WealthEcologyBinding) -> None:
        b.validate()
        if not self._a.evidence_verified(b.evidence_reference): raise FashionContractError("Evidence not verified")
        checks=((b.cruds_impact_metric_id,self._a.impact_metric_verified),(b.seae_impact_link_id,self._a.seae_impact_link_exists),(b.seae_revenue_event_id,self._a.revenue_event_exists))
        for object_id, fn in checks:
            if object_id and not fn(object_id): raise FashionContractError("Referenced Wealth Ecology authority not verified")
        org_checks=((b.rw_commercial_outcome_id,self._a.commercial_outcome_verified),(b.rw_impact_observation_id,self._a.impact_observation_verified),(b.rw_wealth_yield_record_id,self._a.wealth_yield_verified),(b.rw_investment_asset_id,self._a.investment_asset_verified))
        for object_id, fn in org_checks:
            if object_id and not fn(object_id,b.organization_id): raise FashionContractError("Referenced RW authority not verified for organization")

    @staticmethod
    def assert_no_metric_inflation(payload: dict[str, object]) -> None:
        forbidden={"verified_without_evidence","guaranteed_impact","guaranteed_wealth","final_valuation","ownership_final","investment_return_final"}
        if forbidden.intersection(payload): raise FashionContractError("Fashion cannot manufacture verification, guaranteed impact/wealth, valuation, ownership, or investment-return authority")
