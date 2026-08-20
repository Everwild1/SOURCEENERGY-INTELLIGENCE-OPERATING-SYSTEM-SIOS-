"""Governed WITC trade and supply-chain orchestration contracts."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from .domain import OrganizationBinding
from .organization_market_graph import TradeCorridor

class TradeStatus(StrEnum):
    INITIATED="initiated"; DOCUMENTATION="documentation"; COMPLIANCE_REVIEW="compliance_review"; APPROVED="approved"; IN_TRANSIT="in_transit"; DELIVERED="delivered"; RECONCILED="reconciled"; EXCEPTION="exception"; CANCELLED="cancelled"; RESTRICTED="restricted"
class ComplianceStatus(StrEnum):
    PENDING="pending"; PASSED="passed"; FAILED="failed"; RESTRICTED="restricted"; NOT_APPLICABLE="not_applicable"
@dataclass(frozen=True, slots=True)
class ComplianceCheckpoint:
    checkpoint_type: str
    status: ComplianceStatus
    evidence_reference: str=""
    def require_clear(self)->None:
        if self.status not in {ComplianceStatus.PASSED,ComplianceStatus.NOT_APPLICABLE}: raise ValueError("compliance checkpoint is not clear")
        if self.status is ComplianceStatus.PASSED and not self.evidence_reference.strip(): raise ValueError("passed compliance requires evidence")
@dataclass(frozen=True, slots=True)
class LogisticsReference:
    reference_type: str
    external_reference: str
    evidence_reference: str=""
    @property
    def confers_banking_or_custody_authority(self)->bool: return False
@dataclass(frozen=True, slots=True)
class Trade:
    buyer: OrganizationBinding
    seller: OrganizationBinding
    corridor: TradeCorridor
    status: TradeStatus=TradeStatus.INITIATED
    compliance_reference: str=""
    logistics_reference: str=""
    settlement_status: str="not_requested"
    def require_progression(self, checkpoints: tuple[ComplianceCheckpoint,...]=())->None:
        self.buyer.require_commercial_activity(); self.seller.require_commercial_activity()
        if self.buyer.setc_organization_id == self.seller.setc_organization_id: raise ValueError("buyer and seller must differ")
        self.corridor.require_participation()
        if self.status in {TradeStatus.APPROVED,TradeStatus.IN_TRANSIT,TradeStatus.DELIVERED,TradeStatus.RECONCILED}:
            for c in checkpoints: c.require_clear()
            if not self.compliance_reference.strip(): raise ValueError("progressed trade requires compliance reference")
        if self.status is TradeStatus.IN_TRANSIT and not self.logistics_reference.strip(): raise ValueError("in-transit trade requires logistics reference")
        if self.status is TradeStatus.RECONCILED and self.settlement_status != "settled": raise ValueError("reconciliation requires authoritative settlement status")
    @property
    def creates_settlement_finality(self)->bool: return False
@dataclass(frozen=True, slots=True)
class TradeCorrection:
    prior_state: dict
    corrected_state: dict
    reason: str
    evidence_reference: str=""
    def __post_init__(self)->None:
        if not self.reason.strip(): raise ValueError("correction reason is required")
    @property
    def is_append_only_evidence(self)->bool: return True
