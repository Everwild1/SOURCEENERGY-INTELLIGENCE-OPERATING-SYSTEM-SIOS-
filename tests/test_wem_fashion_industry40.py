from uuid import uuid4

import pytest

from setc.fashion.industry40 import (
    FASHION_REFLEX_HISTORICAL_LINEAGE_REFERENCE,
    FASHION_REFLEX_SOURCEENERGY_REFERENCE,
    FashionTechnologyBinding,
    RightsState,
    TechnologyCapability,
    TechnologyReference,
    assert_reflex_sourceenergy_solution,
)
from setc.fashion.service import FashionContractError


def test_third_party_technology_cannot_be_claimed_owned():
    ref = TechnologyReference("EXT-X", "External provider", TechnologyCapability.DIGITAL_TWIN, RightsState.OWNED, "ev:1", third_party=True)
    with pytest.raises(FashionContractError):
        ref.validate()


def test_reviewed_or_licensed_state_requires_rights_evidence():
    ref = TechnologyReference("EXT-X", "External owner", TechnologyCapability.COMPUTER_VISION, RightsState.LICENSED)
    with pytest.raises(FashionContractError):
        ref.validate()


def test_binding_requires_fashion_object_and_implementation_evidence():
    ref = TechnologyReference(FASHION_REFLEX_SOURCEENERGY_REFERENCE, "SourceEnergy Technologies", TechnologyCapability.DIGITAL_TWIN, RightsState.REVIEWED, "ev:rights", third_party=False)
    with pytest.raises(FashionContractError):
        FashionTechnologyBinding(ref, evidence_reference="ev:impl").validate()
    with pytest.raises(FashionContractError):
        FashionTechnologyBinding(ref, design_id=uuid4()).validate()


def test_historical_reflex_lineage_cannot_be_operational_binding():
    historical = TechnologyReference(FASHION_REFLEX_HISTORICAL_LINEAGE_REFERENCE, "historical external technology owner", TechnologyCapability.PROVENANCE, RightsState.EVIDENCE_CANDIDATE, third_party=True)
    with pytest.raises(FashionContractError):
        assert_reflex_sourceenergy_solution(historical)


def test_sourceenergy_can_select_independent_reflex_solution():
    selected = TechnologyReference(FASHION_REFLEX_SOURCEENERGY_REFERENCE, "SourceEnergy Technologies", TechnologyCapability.DIGITAL_TWIN, RightsState.REVIEWED, "ev:rights", third_party=False)
    assert_reflex_sourceenergy_solution(selected)
    FashionTechnologyBinding(selected, design_id=uuid4(), evidence_reference="ev:implementation").validate()


def test_external_component_rights_remain_external():
    ref = TechnologyReference("PARTNER-TECH-1", "Technology Partner", TechnologyCapability.SMART_PRODUCTION, RightsState.LICENSED, "license:1", sourceenergy_derivative_reference="Fashion RefleX implementation", third_party=True)
    ref.validate()
    assert ref.third_party is True
    assert ref.rights_state is RightsState.LICENSED
