from uuid import uuid4

import pytest

from setc.fashion.industry40 import FashionTechnologyBinding, RightsState, TechnologyCapability, TechnologyReference
from setc.fashion.industry40_bindings import FashionIndustry40BindingValidator, RegisteredTechnology, VerifiedEvidence
from setc.fashion.service import FashionContractError


class Authorities:
    def __init__(self):
        self.verified = {"impl-1", "rights-1"}
        self.objects = set()
        self.supply_nodes = set()
        self.productions = set()
        self.shipments = set()

    def technology(self, reference):
        if reference == "TECH-1":
            return RegisteredTechnology(reference, "EXT-OWNER", "active", 2)
        return None

    def evidence(self, reference):
        if reference in self.verified:
            return VerifiedEvidence(reference, "verified")
        return None

    def fashion_object_exists(self, resource, object_id): return (resource, object_id) in self.objects
    def supply_node_verified(self, object_id): return object_id in self.supply_nodes
    def seae_production_exists(self, object_id): return object_id in self.productions
    def rgl_shipment_exists(self, object_id): return object_id in self.shipments


def technology(rights=RightsState.EVIDENCE_CANDIDATE, rights_ref=None):
    return TechnologyReference("TECH-1", "External Owner", TechnologyCapability.DIGITAL_TWIN, rights, rights_ref, third_party=True)


def test_binding_requires_authoritative_registered_technology_and_target():
    authorities = Authorities(); design_id = uuid4(); authorities.objects.add(("designs", design_id))
    FashionIndustry40BindingValidator(authorities).validate(FashionTechnologyBinding(technology(), design_id=design_id, evidence_reference="impl-1"))


def test_unregistered_technology_fails_closed():
    authorities = Authorities(); design_id = uuid4(); authorities.objects.add(("designs", design_id))
    tech = TechnologyReference("MISSING", "External", TechnologyCapability.DIGITAL_TWIN, RightsState.EVIDENCE_CANDIDATE)
    with pytest.raises(FashionContractError):
        FashionIndustry40BindingValidator(authorities).validate(FashionTechnologyBinding(tech, design_id=design_id, evidence_reference="impl-1"))


def test_licensed_state_requires_verified_rights_evidence():
    authorities = Authorities(); design_id = uuid4(); authorities.objects.add(("designs", design_id)); authorities.verified.discard("rights-1")
    with pytest.raises(FashionContractError):
        FashionIndustry40BindingValidator(authorities).validate(FashionTechnologyBinding(technology(RightsState.LICENSED, "rights-1"), design_id=design_id, evidence_reference="impl-1"))


def test_manufacturing_chain_preserves_gsc_seae_rgl_authority():
    authorities = Authorities(); order = uuid4(); node = uuid4(); production = uuid4(); shipment = uuid4()
    authorities.objects.add(("production_orders", order)); authorities.supply_nodes.add(node); authorities.productions.add(production); authorities.shipments.add(shipment)
    FashionIndustry40BindingValidator(authorities).validate_manufacturing_chain(production_order_id=order, supply_node_id=node, seae_production_id=production, shipment_id=shipment)


def test_unverified_supply_node_fails_closed():
    authorities = Authorities(); order = uuid4(); authorities.objects.add(("production_orders", order))
    with pytest.raises(FashionContractError):
        FashionIndustry40BindingValidator(authorities).validate_manufacturing_chain(production_order_id=order, supply_node_id=uuid4())
