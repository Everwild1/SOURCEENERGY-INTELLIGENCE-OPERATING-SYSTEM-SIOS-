"""WF-DB-010 evidence-gated 90-day Fashion pilot governance."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol
from uuid import UUID
from .service import FashionContractError

class PilotPhase(StrEnum):
    MOBILIZE="mobilize"; PROTECT_VALIDATE="protect_validate"; PRODUCE_CERTIFY="produce_certify"; MARKET_TRADE="market_trade"; CAPITAL_MEASURE="capital_measure"; LAUNCH_DECISION="launch_decision"

class GateOutcome(StrEnum):
    APPROVED="approved"; REMEDIATION_REQUIRED="remediation_required"; REJECTED="rejected"; WITHDRAWN="withdrawn"

@dataclass(frozen=True, slots=True)
class PilotGateBinding:
    organization_id: UUID
    brand_id: UUID
    phase: PilotPhase
    evidence_reference: str
    accelerator_transition_reference: str
    market_access_reference: str | None = None
    capital_readiness_reference: str | None = None
    wealth_ecology_reference: str | None = None

    def validate(self) -> None:
        if not self.evidence_reference.strip() or not self.accelerator_transition_reference.strip():
            raise FashionContractError("Pilot gate requires evidence and accelerator transition")
        if self.phase in {PilotPhase.MARKET_TRADE, PilotPhase.CAPITAL_MEASURE, PilotPhase.LAUNCH_DECISION} and not self.market_access_reference:
            raise FashionContractError("Commercial pilot phases require market-access evidence")
        if self.phase in {PilotPhase.CAPITAL_MEASURE, PilotPhase.LAUNCH_DECISION} and not self.capital_readiness_reference:
            raise FashionContractError("Capital phases require capital-readiness evidence")
        if self.phase == PilotPhase.LAUNCH_DECISION and not self.wealth_ecology_reference:
            raise FashionContractError("Launch decision requires Wealth Ecology evidence")

class PilotAuthorityReader(Protocol):
    def organization_active(self, object_id: UUID) -> bool: ...
    def brand_exists(self, object_id: UUID) -> bool: ...
    def evidence_verified(self, reference: str) -> bool: ...
    def accelerator_gate_approved(self, reference: str, organization_id: UUID) -> bool: ...
    def market_access_ready(self, reference: str, organization_id: UUID) -> bool: ...
    def capital_readiness_satisfied(self, reference: str, organization_id: UUID) -> bool: ...
    def wealth_ecology_verified(self, reference: str, organization_id: UUID) -> bool: ...

class FashionPilotValidator:
    def __init__(self, authorities: PilotAuthorityReader) -> None: self._a=authorities
    def evaluate(self, b: PilotGateBinding) -> GateOutcome:
        b.validate()
        if not self._a.organization_active(b.organization_id) or not self._a.brand_exists(b.brand_id): return GateOutcome.REJECTED
        if not self._a.evidence_verified(b.evidence_reference): return GateOutcome.REMEDIATION_REQUIRED
        if not self._a.accelerator_gate_approved(b.accelerator_transition_reference,b.organization_id): return GateOutcome.REMEDIATION_REQUIRED
        if b.market_access_reference and not self._a.market_access_ready(b.market_access_reference,b.organization_id): return GateOutcome.REMEDIATION_REQUIRED
        if b.capital_readiness_reference and not self._a.capital_readiness_satisfied(b.capital_readiness_reference,b.organization_id): return GateOutcome.REMEDIATION_REQUIRED
        if b.wealth_ecology_reference and not self._a.wealth_ecology_verified(b.wealth_ecology_reference,b.organization_id): return GateOutcome.REMEDIATION_REQUIRED
        return GateOutcome.APPROVED

    @staticmethod
    def assert_no_launch_authority_escalation(payload: dict[str, object]) -> None:
        forbidden={"regulatory_approved","certification_final","financing_approved","settlement_final","payment_final","guaranteed_launch","guaranteed_return","wealth_final"}
        if forbidden.intersection(payload): raise FashionContractError("Pilot governance cannot manufacture regulatory, certification, financing, settlement, launch, return, or wealth authority")
