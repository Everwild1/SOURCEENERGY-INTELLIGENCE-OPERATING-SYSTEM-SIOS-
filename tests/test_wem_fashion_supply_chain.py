from uuid import uuid4

import pytest

from setc.fashion.service import FashionContractError
from setc.fashion.supply_chain import FashionSupplyChainBinding, FashionSupplyChainValidator, TradeBoundaryDecision


class Authorities:
    def __init__(self):
        self.objects = set()
        self.supply_nodes = set()
        self.programs = set()
        self.shipments = set()
        self.opportunities = set()
        self.transactions = set()
        self.verified_evidence = set()
        self.customs_ok = set()
        self.trade_ok = set()

    def fashion_object_exists(self, resource, object_id): return (resource, object_id) in self.objects
    def gsc_supply_node_verified(self, object_id): return object_id in self.supply_nodes
    def gsc_distribution_program_exists(self, object_id): return object_id in self.programs
    def rgl_shipment_exists(self, object_id): return object_id in self.shipments
    def rgl_customs_clearance_satisfied(self, object_id): return object_id in self.customs_ok
    def wim_opportunity_exists(self, object_id): return object_id in self.opportunities
    def wim_transaction_exists(self, object_id): return object_id in self.transactions
    def wim_trade_compliance_satisfied(self, object_id): return object_id in self.trade_ok
    def evidence_verified(self, reference): return reference in self.verified_evidence


def valid_fixture():
    a = Authorities()
    order, batch, node, shipment, opportunity, transaction = [uuid4() for _ in range(6)]
    a.objects |= {("production_orders", order), ("production_batches", batch)}
    a.supply_nodes.add(node)
    a.shipments.add(shipment)
    a.opportunities.add(opportunity)
    a.transactions.add(transaction)
    a.verified_evidence.add("EV-1")
    return a, FashionSupplyChainBinding(order, node, production_batch_id=batch, rgl_shipment_id=shipment, wim_opportunity_id=opportunity, wim_transaction_id=transaction, evidence_reference="EV-1"), shipment, transaction


def test_complete_authority_chain_validates():
    a, binding, _, _ = valid_fixture()
    FashionSupplyChainValidator(a).validate_binding(binding)


def test_unverified_supply_node_fails_closed():
    a, binding, _, _ = valid_fixture()
    a.supply_nodes.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(binding)


def test_unverified_evidence_fails_closed():
    a, binding, _, _ = valid_fixture()
    a.verified_evidence.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(binding)


def test_trade_requires_opportunity_context():
    order, node = uuid4(), uuid4()
    with pytest.raises(FashionContractError):
        FashionSupplyChainBinding(order, node, wim_transaction_id=uuid4(), evidence_reference="EV").validate()


def test_shipment_requires_batch_context():
    with pytest.raises(FashionContractError):
        FashionSupplyChainBinding(uuid4(), uuid4(), rgl_shipment_id=uuid4(), evidence_reference="EV").validate()


def test_readiness_uses_rgl_customs_and_wim_compliance():
    a, binding, shipment, transaction = valid_fixture()
    a.customs_ok.add(shipment); a.trade_ok.add(transaction)
    decision = FashionSupplyChainValidator(a).trade_readiness(binding)
    assert decision.market_access_ready and decision.logistics_ready and decision.compliance_ready
    assert decision.settlement_final is False


def test_fashion_cannot_assert_settlement_finality():
    with pytest.raises(FashionContractError):
        TradeBoundaryDecision(True, True, True, settlement_final=True).validate()
