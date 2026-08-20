"""Versioned, evidence-backed Wealth Ecology measurement contracts."""
from __future__ import annotations
from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum

class MeasurementKind(StrEnum):
    ESTIMATE="estimate"; OBSERVED="observed"; VERIFIED="verified"
class MetricFamily(StrEnum):
    JOBS="jobs"; LOCAL_SUPPLIER_PARTICIPATION="local_supplier_participation"; SME_REVENUE="sme_revenue"; DIASPORA_CAPITAL="diaspora_capital"; REGIONAL_TRADE="regional_trade"; KNOWLEDGE_TRANSFER="knowledge_transfer"; PRODUCTIVE_CAPACITY="productive_capacity"; COMMUNITY_WEALTH="community_wealth"; TAX_BASE="tax_base"; ENVIRONMENTAL_IMPACT="environmental_impact"
@dataclass(frozen=True, slots=True)
class MetricDefinition:
    code:str; name:str; family:MetricFamily; methodology_version:str; unit:str
    def __post_init__(self)->None:
        if not self.code.strip() or not self.methodology_version.strip(): raise ValueError("metric code and methodology version are required")
@dataclass(frozen=True, slots=True)
class ImpactMeasurement:
    definition:MetricDefinition
    subject_reference:str
    value:Decimal
    kind:MeasurementKind
    evidence_reference:str
    deduplication_key:str
    confidence_score:Decimal|None=None
    def require_reportable(self)->None:
        if not self.subject_reference.strip(): raise ValueError("measurement subject is required")
        if not self.evidence_reference.strip(): raise ValueError("measurement evidence is required")
        if not self.deduplication_key.strip(): raise ValueError("anti-double-counting key is required")
        if self.kind is MeasurementKind.VERIFIED and (self.confidence_score is None or self.confidence_score < Decimal("0.8")): raise ValueError("verified measurement requires confidence >= 0.8")
    @property
    def creates_financial_or_economic_authority(self)->bool: return False
@dataclass(frozen=True, slots=True)
class ImpactCorrection:
    prior_measurement_reference:str
    corrected_measurement_reference:str
    reason:str
    evidence_reference:str
    def __post_init__(self)->None:
        if self.prior_measurement_reference == self.corrected_measurement_reference: raise ValueError("correction must reference a distinct measurement")
        if not self.reason.strip() or not self.evidence_reference.strip(): raise ValueError("correction reason and evidence are required")
    @property
    def preserves_history(self)->bool: return True
@dataclass(frozen=True, slots=True)
class WealthEcologyLoop:
    research_reference:str
    commercialization_reference:str
    market_reference:str
    transaction_reference:str
    impact_reference:str
    feedback_research_reference:str
    def require_complete(self)->None:
        values=(self.research_reference,self.commercialization_reference,self.market_reference,self.transaction_reference,self.impact_reference,self.feedback_research_reference)
        if any(not v.strip() for v in values): raise ValueError("research-commercialization-market-transaction-impact-research loop must be complete")
