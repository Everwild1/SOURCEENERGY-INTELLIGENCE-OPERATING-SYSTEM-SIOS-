from uuid import uuid4

import pytest

from setc.fashion.industry40 import (
    FASHION_REFLEX_LINEAGE,
    FashionTechnologyBinding,
    RightsState,
    TechnologyCapability,
    TechnologyReference,
)
from setc.fashion.service import FashionContractError


def test_third_party_technology_cannot_be_claimed_owned():
    ref = TechnologyReference("NASA-X", "NASA", TechnologyCapability.DIGITAL_TWIN, RightsState.OWNED, "ev:1", third_party=True)
    with pytest.raises(FashionContractError):
        ref.validate()


def test_reviewed_or_licensed_state_requires_rights_evidence():
    ref = TechnologyReference("EXT-X", "External owner", TechnologyCapability.COMPUTER_VISION, RightsState.LICENSED)
    with pytest.raises(FashionContractError):
        ref.validate()


def test_binding_requires_fashion_object_and_implementation_evidence():
    with pytest.raises(FashionContractError):
        FashionTechnologyBinding(FASHION_REFLEX_LINEAGE, evidence_reference="ev:impl").validate()
    with pytest.raises(FashionContractError):
        FashionTechnologyBinding(FASHION_REFLEX_LINEAGE, design_id=uuid4()).validate()


def test_evidence_candidate_reflex_can_bind_without_ownership_claim():
    binding = FashionTechnologyBinding(FASHION_REFLEX_LINEAGE, design_id=uuid4(), evidence_reference="seg:techtrans:001")
    binding.validate()


def test_sourceenergy_derivative_reference_does_not_change_underlying_rights():
    ref = TechnologyReference(
        "NASA-TECH-1",
        "NASA",
        TechnologyCapability.SMART_PRODUCTION,
        RightsState.EVIDENCE_CANDIDATE,
        sourceenergy_derivative_reference="SourceEnergy commercialization mapping",
        third_party=True,
    )
    ref.validate()
    assert ref.third_party is True
    assert ref.rights_state is RightsState.EVIDENCE_CANDIDATE
