"""WF-DB-007 governed Fashion capitalization gates and authority boundaries."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID

from .service import FashionContractError


class CapitalGate(StrEnum):
    C0_FORMATION = "c0_formation"
    C1_PRODUCTION = "c1_production"
    C2_WORKING_CAPITAL = "c2_working_capital"
    C3_TRANSACTION_FINANCE = "c3_transaction_finance"
    C4_GROWTH_CAPITAL = "c4_growth_capital"
    C5_WEALTH_CONVERSION = "c5_wealth_conversion"


@dataclass(frozen=True, slots=True)
class FashionCapitalBinding:
    organization_id: UUID
    brand_id: UUID
    readiness_profile_id: UUID
    gate: CapitalGate
    evidence_reference: str
    capital_request_id: UUID | None = None
    capital_referral_id: UUID | None = None
    capital_event_id: UUID | None = None
    wealth_yield_record_id: UUID | None = None
    investment_asset_id: UUID | None = None

    def validate(self) -> None:
        if not self.evidence_reference.strip():
            raise FashionContractError("Capital gate requires evidence")
        if self.capital_referral_id and not self.capital_request_id:
            raise FashionContractError("Capital referral requires a capital request")
        if self.gate == CapitalGate.C5_WEALTH_CONVERSION and not (
            self.wealth_yield_record_id or self.investment_asset_id
        ):
            raise FashionContractError("C5 requires authoritative wealth or asset evidence")


@dataclass(frozen=True, slots=True)
class CapitalReadinessDecision:
    gate: CapitalGate
    enterprise_ready: bool
    evidence_ready: bool
    request_exists: bool
    referral_exists: bool
    verified_capital_event: bool
    wealth_conversion_evidence: bool

    @property
    def ready(self) -> bool:
        base = self.enterprise_ready and self.evidence_ready
        if self.gate == CapitalGate.C5_WEALTH_CONVERSION:
            return base and self.wealth_conversion_evidence
        return base


class CapitalAuthorityReader(Protocol):
    def fashion_brand_exists(self, brand_id: UUID) -> bool: ...
    def capital_readiness_satisfied(self, profile_id: UUID, organization_id: UUID) -> bool: ...
    def evidence_verified(self, reference: str) -> bool: ...
    def capital_request_exists(self, request_id: UUID, organization_id: UUID) -> bool: ...
    def capital_referral_exists(self, referral_id: UUID, request_id: UUID) -> bool: ...
    def capital_event_verified(self, event_id: UUID, organization_id: UUID) -> bool: ...
    def wealth_yield_verified(self, record_id: UUID, organization_id: UUID) -> bool: ...
    def investment_asset_verified(self, asset_id: UUID, organization_id: UUID) -> bool: ...


class FashionCapitalValidator:
    def __init__(self, authorities: CapitalAuthorityReader) -> None:
        self._authorities = authorities

    def evaluate(self, binding: FashionCapitalBinding) -> CapitalReadinessDecision:
        binding.validate()
        enterprise_ready = (
            self._authorities.fashion_brand_exists(binding.brand_id)
            and self._authorities.capital_readiness_satisfied(binding.readiness_profile_id, binding.organization_id)
        )
        evidence_ready = self._authorities.evidence_verified(binding.evidence_reference)
        request_exists = bool(binding.capital_request_id) and self._authorities.capital_request_exists(
            binding.capital_request_id, binding.organization_id
        )
        referral_exists = False
        if binding.capital_referral_id and binding.capital_request_id:
            referral_exists = self._authorities.capital_referral_exists(
                binding.capital_referral_id, binding.capital_request_id
            )
        verified_capital_event = bool(binding.capital_event_id) and self._authorities.capital_event_verified(
            binding.capital_event_id, binding.organization_id
        )
        wealth_conversion_evidence = False
        if binding.wealth_yield_record_id:
            wealth_conversion_evidence = self._authorities.wealth_yield_verified(
                binding.wealth_yield_record_id, binding.organization_id
            )
        if binding.investment_asset_id:
            wealth_conversion_evidence = wealth_conversion_evidence or self._authorities.investment_asset_verified(
                binding.investment_asset_id, binding.organization_id
            )
        return CapitalReadinessDecision(
            gate=binding.gate,
            enterprise_ready=enterprise_ready,
            evidence_ready=evidence_ready,
            request_exists=request_exists,
            referral_exists=referral_exists,
            verified_capital_event=verified_capital_event,
            wealth_conversion_evidence=wealth_conversion_evidence,
        )

    @staticmethod
    def assert_no_financial_authority(payload: dict[str, object]) -> None:
        forbidden = {
            "financing_approved", "credit_approved", "investment_approved",
            "securities_status", "custody_final", "settlement_final",
            "payment_final", "guaranteed_return", "investment_performance_final",
        }
        if forbidden.intersection(payload):
            raise FashionContractError(
                "Fashion capitalization cannot assert financing, investment, securities, custody, settlement, payment, or performance authority"
            )
