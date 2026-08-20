"""Fail-closed cross-context integration contracts for CRUDS Universe."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum


class SettlementRail(StrEnum):
    FIAT_EXTERNAL = "fiat_external"
    SOURCE_COIN = "source_coin"


@dataclass(frozen=True, slots=True)
class OpportunityResponseReference:
    value: str

    @property
    def creates_binding_contract(self) -> bool:
        return False

    @property
    def creates_transaction(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class WimMarketAccessRequest:
    request_reference: str
    request_type: str
    work_reference: str

    @property
    def owns_wim_workflow(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class SettlementRequest:
    request_reference: str
    idempotency_key: str
    rail: SettlementRail
    amount: Decimal | None = None
    currency_code: str | None = None

    @property
    def is_final(self) -> bool:
        return False

    @property
    def mutates_source_coin_ledger(self) -> bool:
        return False


@dataclass(frozen=True, slots=True)
class IntelligenceProjection:
    subject_reference: str
    projection_version: str
    methodology_version: str

    @property
    def is_authoritative_transaction_state(self) -> bool:
        return False
