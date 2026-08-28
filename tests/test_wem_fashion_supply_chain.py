from uuid import uuid4

import pytest

from setc.fashion.service import FashionContractError
from setc.fashion.supply_chain import FashionSupplyChainBinding, FashionSupplyChainValidator, TradeBoundaryDecision


class Authorities:
    def __init__(self):
        self.objects=set(); self.supply_nodes=set(); self.programs=set(); self.shipments=set(); self.opportunities=set(); self.transactions=set(); self.verified_evidence=set(); self.customs_ok=set(); self.trade_ok=set()
        self.order_nodes=set(); self.batch_orders=set(); self.batch_nodes=set(); self.batch_shipments=set(); self.program_nodes=set(); self.shipment_nodes=set(); self.transaction_opportunities=set(); self.shipment_transactions=set()
    def fashion_object_exists(self,r,i): return (r,i) in self.objects
    def gsc_supply_node_verified(self,i): return i in self.supply_nodes
    def gsc_distribution_program_exists(self,i): return i in self.programs
    def rgl_shipment_exists(self,i): return i in self.shipments
    def rgl_customs_clearance_satisfied(self,i): return i in self.customs_ok
    def wim_opportunity_exists(self,i): return i in self.opportunities
    def wim_transaction_exists(self,i): return i in self.transactions
    def wim_trade_compliance_satisfied(self,i): return i in self.trade_ok
    def evidence_verified(self,r): return r in self.verified_evidence
    def production_order_uses_supply_node(self,o,n): return (o,n) in self.order_nodes
    def production_batch_belongs_to_order(self,b,o): return (b,o) in self.batch_orders
    def production_batch_origin_matches_node(self,b,n): return (b,n) in self.batch_nodes
    def production_batch_shipment_matches(self,b,s): return (b,s) in self.batch_shipments
    def distribution_program_origin_matches_node(self,p,n): return (p,n) in self.program_nodes
    def shipment_origin_matches_supply_node_facility(self,s,n): return (s,n) in self.shipment_nodes
    def transaction_belongs_to_opportunity(self,t,o): return (t,o) in self.transaction_opportunities
    def shipment_corridor_matches_transaction(self,s,t): return (s,t) in self.shipment_transactions


def valid_fixture():
    a=Authorities(); order,batch,node,shipment,opportunity,transaction=[uuid4() for _ in range(6)]
    a.objects|={("production_orders",order),("production_batches",batch)}; a.supply_nodes.add(node); a.shipments.add(shipment); a.opportunities.add(opportunity); a.transactions.add(transaction); a.verified_evidence.add("EV-1")
    a.order_nodes.add((order,node)); a.batch_orders.add((batch,order)); a.batch_nodes.add((batch,node)); a.batch_shipments.add((batch,shipment)); a.shipment_nodes.add((shipment,node)); a.transaction_opportunities.add((transaction,opportunity)); a.shipment_transactions.add((shipment,transaction))
    binding=FashionSupplyChainBinding(order,node,production_batch_id=batch,rgl_shipment_id=shipment,wim_opportunity_id=opportunity,wim_transaction_id=transaction,evidence_reference="EV-1")
    return a,binding,shipment,transaction


def test_complete_authority_chain_validates():
    a,b,_,_=valid_fixture(); FashionSupplyChainValidator(a).validate_binding(b)

def test_unverified_supply_node_fails_closed():
    a,b,_,_=valid_fixture(); a.supply_nodes.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_order_supply_node_mismatch_fails_closed():
    a,b,_,_=valid_fixture(); a.order_nodes.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_batch_order_mismatch_fails_closed():
    a,b,_,_=valid_fixture(); a.batch_orders.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_shipment_facility_mismatch_fails_closed():
    a,b,_,_=valid_fixture(); a.shipment_nodes.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_transaction_opportunity_mismatch_fails_closed():
    a,b,_,_=valid_fixture(); a.transaction_opportunities.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_shipment_transaction_corridor_mismatch_fails_closed():
    a,b,_,_=valid_fixture(); a.shipment_transactions.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_unverified_evidence_fails_closed():
    a,b,_,_=valid_fixture(); a.verified_evidence.clear()
    with pytest.raises(FashionContractError): FashionSupplyChainValidator(a).validate_binding(b)

def test_readiness_uses_rgl_customs_and_wim_compliance():
    a,b,s,t=valid_fixture(); a.customs_ok.add(s); a.trade_ok.add(t)
    d=FashionSupplyChainValidator(a).trade_readiness(b)
    assert d.market_access_ready and d.logistics_ready and d.compliance_ready and d.relationship_integrity
    assert d.settlement_final is False

def test_fashion_cannot_assert_settlement_finality():
    with pytest.raises(FashionContractError): TradeBoundaryDecision(True,True,True,True,settlement_final=True).validate()
