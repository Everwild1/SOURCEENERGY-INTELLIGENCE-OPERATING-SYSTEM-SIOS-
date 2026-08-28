"""WF-DB-004 governed Industry 4.0 technology-selection contracts."""
from __future__ import annotations
from dataclasses import dataclass
from enum import StrEnum
from typing import Mapping
from uuid import UUID
from .service import FashionContractError

class TechnologyCapability(StrEnum):
    AI_ASSISTED_DESIGN="ai_assisted_design"; DIGITAL_TWIN="digital_twin"; THREE_D_PROTOTYPING="3d_prototyping"
    VIRTUAL_FITTING="virtual_fitting"; MATERIAL_INTELLIGENCE="material_intelligence"; DEMAND_FORECASTING="demand_forecasting"
    SMART_PRODUCTION="smart_production"; IOT_MANUFACTURING="iot_manufacturing"; COMPUTER_VISION="computer_vision"
    INVENTORY_OPTIMIZATION="inventory_optimization"; PROVENANCE="provenance"; LIFECYCLE_INTELLIGENCE="lifecycle_intelligence"

class RightsState(StrEnum):
    UNKNOWN="unknown"; EVIDENCE_CANDIDATE="evidence_candidate"; REVIEWED="reviewed"; LICENSED="licensed"; OWNED="owned"; RESTRICTED="restricted"

@dataclass(frozen=True, slots=True)
class TechnologyReference:
    technology_reference: str
    provider_or_owner: str
    capability: TechnologyCapability
    rights_state: RightsState
    rights_evidence_reference: str | None=None
    sourceenergy_derivative_reference: str | None=None
    third_party: bool=True
    def validate(self)->None:
        if not self.technology_reference.strip() or not self.provider_or_owner.strip(): raise FashionContractError("Technology reference and provider/owner are required")
        if self.third_party and self.rights_state is RightsState.OWNED: raise FashionContractError("Third-party technology cannot be represented as SourceEnergy-owned")
        if self.rights_state in {RightsState.REVIEWED,RightsState.LICENSED,RightsState.OWNED} and not self.rights_evidence_reference: raise FashionContractError("Reviewed/licensed/owned technology status requires rights evidence")

@dataclass(frozen=True, slots=True)
class FashionTechnologyBinding:
    technology: TechnologyReference
    design_id: UUID|None=None; product_model_id: UUID|None=None; production_order_id: UUID|None=None; production_batch_id: UUID|None=None; material_id: UUID|None=None
    evidence_reference: str|None=None
    implementation_profile: Mapping[str,object]|None=None
    def validate(self)->None:
        self.technology.validate()
        if not any((self.design_id,self.product_model_id,self.production_order_id,self.production_batch_id,self.material_id)): raise FashionContractError("Industry 4.0 technology must bind to a Fashion asset or production object")
        if not self.evidence_reference: raise FashionContractError("Technology binding requires implementation evidence")

# Fashion RefleX is a SourceEnergy product/venture concept, not a NASA technology binding.
# Historical NASA T2U materials may remain archival evidence of prior commercialization work,
# but they are not an implementation dependency, technology authority, or product constraint.
FASHION_REFLEX_SOURCEENERGY_REFERENCE="SOURCEENERGY-TECH:FASHION-REFLEX"
FASHION_REFLEX_HISTORICAL_LINEAGE_REFERENCE="SEG-IP-TECHTRANS-001:FASHION-REFLEX"

def assert_reflex_sourceenergy_solution(reference: TechnologyReference)->None:
    """Require any operational Fashion RefleX technology to use a separately selected SourceEnergy solution."""
    if reference.technology_reference == FASHION_REFLEX_HISTORICAL_LINEAGE_REFERENCE:
        raise FashionContractError("Historical NASA/T2U Fashion RefleX lineage is archival evidence only and cannot be used as the operational technology binding")
    reference.validate()
