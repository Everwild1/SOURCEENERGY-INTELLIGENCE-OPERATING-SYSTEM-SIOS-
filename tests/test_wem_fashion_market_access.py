from uuid import uuid4

import pytest

from setc.fashion.market_access import FashionMarketAccessValidator, MarketAccessBinding
from setc.fashion.service import FashionContractError


class Authorities:
    def __init__(self):
        self.fail = set()
    def fashion_object_exists(self, resource, object_id): return "fashion_object" not in self.fail
    def organization_active(self, organization_id): return "organization" not in self.fail
    def wim_product_verified(self, product_id): return "wim_product" not in self.fail
    def procurement_readiness_satisfied(self, profile_id, organization_id): return "procurement_readiness" not in self.fail
    def trade_readiness_satisfied(self, profile_id, organization_id): return "trade_readiness" not in self.fail
    def evidence_verified(self, reference): return reference == "E-VERIFIED"
    def market_access_request_exists(self, request_id): return "market_request" not in self.fail
    def wim_opportunity_exists(self, opportunity_id): return "wim_opportunity" not in self.fail
    def procurement_opportunity_exists(self, opportunity_id): return "procurement_opportunity" not in self.fail
    def wim_transaction_exists(self, transaction_id): return "wim_transaction" not in self.fail
    def logistics_ready(self, transaction_id): return "logistics" not in self.fail
    def brand_owned_by_organization(self, brand_id, organization_id): return "brand_owner" not in self.fail
    def brand_wim_organization_matches(self, brand_id, organization_id): return "brand_wim_org" not in self.fail
    def product_model_belongs_to_brand(self, product_model_id, brand_id): return "product_brand" not in self.fail
    def product_model_wim_product_matches(self, product_model_id, wim_product_id): return "product_wim_product" not in self.fail
    def wim_product_owned_by_organization(self, wim_product_id, organization_id): return "wim_product_owner" not in self.fail
    def market_access_request_matches_product(self, request_id, product_model_id): return "request_product" not in self.fail
    def market_access_request_matches_opportunity(self, request_id, opportunity_id): return "request_opportunity" not in self.fail
    def procurement_opportunity_admissible_for_organization(self, opportunity_id, organization_id): return "procurement_admissibility" not in self.fail
    def wim_transaction_belongs_to_opportunity(self, transaction_id, opportunity_id): return "transaction_opportunity" not in self.fail
    def wim_transaction_seller_matches_organization(self, transaction_id, organization_id): return "transaction_seller" not in self.fail


def binding(**changes):
    values = dict(
        brand_id=uuid4(), product_model_id=uuid4(), organization_id=uuid4(),
        wim_product_service_id=uuid4(), procurement_readiness_profile_id=uuid4(),
        trade_readiness_profile_id=uuid4(), evidence_reference="E-VERIFIED",
    )
    values.update(changes)
    return MarketAccessBinding(**values)


def test_market_readiness_requires_relationship_integrity():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(binding())
    assert readiness.market_ready is True
    assert readiness.relationship_integrity is True


@pytest.mark.parametrize("failure", ["brand_owner", "brand_wim_org", "product_brand", "product_wim_product", "wim_product_owner"])
def test_product_enterprise_relationship_mismatch_fails_market_ready(failure):
    a = Authorities(); a.fail.add(failure)
    readiness = FashionMarketAccessValidator(a).evaluate(binding())
    assert readiness.relationship_integrity is False
    assert readiness.market_ready is False


def test_unverified_evidence_fails_market_ready():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(binding(evidence_reference="E-NO"))
    assert readiness.evidence_ready is False
    assert readiness.market_ready is False


def test_market_access_request_product_mismatch_fails_closed():
    a = Authorities(); a.fail.add("request_product")
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(a).evaluate(binding(market_access_request_id=uuid4()))


def test_market_access_request_opportunity_mismatch_fails_closed():
    a = Authorities(); a.fail.add("request_opportunity")
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(a).evaluate(binding(market_access_request_id=uuid4(), wim_opportunity_id=uuid4()))


def test_procurement_opportunity_must_be_admissible_for_enterprise():
    a = Authorities(); a.fail.add("procurement_admissibility")
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(a).evaluate(binding(procurement_opportunity_id=1))


def test_transaction_requires_wim_opportunity_context():
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(Authorities()).evaluate(binding(wim_transaction_id=uuid4()))


def test_transaction_opportunity_mismatch_fails_closed():
    a = Authorities(); a.fail.add("transaction_opportunity")
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(a).evaluate(binding(wim_opportunity_id=uuid4(), wim_transaction_id=uuid4()))


def test_transaction_seller_must_match_fashion_enterprise():
    a = Authorities(); a.fail.add("transaction_seller")
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(a).evaluate(binding(wim_opportunity_id=uuid4(), wim_transaction_id=uuid4()))


def test_transaction_can_reference_logistics_without_creating_finality():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(binding(wim_opportunity_id=uuid4(), wim_transaction_id=uuid4()))
    assert readiness.logistics_ready is True


def test_settlement_and_custody_authority_escalation_is_rejected():
    validator = FashionMarketAccessValidator(Authorities())
    with pytest.raises(FashionContractError): validator.assert_no_settlement_authority({"settlement_final": True})
    with pytest.raises(FashionContractError): validator.assert_no_settlement_authority({"custody_final": True})
