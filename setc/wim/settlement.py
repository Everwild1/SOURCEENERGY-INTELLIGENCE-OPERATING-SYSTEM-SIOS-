"""WIM settlement orchestration boundaries.

WIM requests and reconciles settlement. It never mutates Source Coin balances,
ledger, treasury or supply and never self-confers settlement finality.
"""
from __future__ import annotations
from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum

class SettlementRail(StrEnum):
    FIAT_EXTERNAL="fiat_external"
    SOURCE_COIN="source_coin"

class SettlementStatus(StrEnum):
    REQUESTED="requested"; PENDING="pending"; CONFIRMED="confirmed"; FAILED="failed"; CANCELLED="cancelled"; RESTRICTED="restricted"

@dataclass(frozen=True, slots=True)
class SettlementRequest:
    transaction_reference: str
    rail: SettlementRail
    request_reference: str
    idempotency_key: str
    correlation_id: str
    amount: Decimal|None=None
    currency_code: str|None=None
    compliance_reference: str=""
    def __post_init__(self)->None:
        for value,label in ((self.transaction_reference,"transaction_reference"),(self.request_reference,"request_reference"),(self.idempotency_key,"idempotency_key"),(self.correlation_id,"correlation_id")):
            if not value.strip(): raise ValueError(f"{label} is required")
        if self.amount is not None and self.amount < 0: raise ValueError("amount cannot be negative")
    @property
    def can_mutate_source_coin_ledger(self)->bool: return False
    @property
    def confers_settlement_finality(self)->bool: return False

@dataclass(frozen=True, slots=True)
class AuthoritativeSettlementConfirmation:
    rail: SettlementRail
    authoritative_reference: str
    status: SettlementStatus
    def require_final(self)->None:
        if self.status is not SettlementStatus.CONFIRMED: raise ValueError("authoritative settlement is not confirmed")
        if not self.authoritative_reference.strip(): raise ValueError("authoritative confirmation reference is required")
        if self.rail is SettlementRail.SOURCE_COIN and not self.authoritative_reference.startswith("SC-"):
            raise ValueError("Source Coin confirmation must originate from authoritative Source Coin domain")

class FiatSettlementAdapter:
    """Port only; implementation belongs to an authorized external fiat rail."""
    def submit(self, request: SettlementRequest)->str: raise NotImplementedError

class SourceCoinEconomicRequestAdapter:
    """Port only; cannot expose direct balance/ledger/treasury/supply mutation."""
    def submit_economic_request(self, request: SettlementRequest)->str: raise NotImplementedError

@dataclass(frozen=True, slots=True)
class SettlementCorrection:
    prior_state: dict
    corrected_state: dict
    reason: str
    evidence_reference: str=""
    def __post_init__(self)->None:
        if not self.reason.strip(): raise ValueError("correction reason is required")
    @property
    def is_compensating_append_only_evidence(self)->bool: return True
