from uuid import uuid4

import pytest

from setc.fashion.market_access import FashionMarketAccessValidator, MarketAccessBinding
from setc.fashion.service import FashionContractError


class Authorities:
    def fashion_object_exists(self, resource, object_id): return True
    def organization_active(self, organization_id): return True
    def wim_product_verified(self, product_id): return True
    def procurement_readiness_satisfied(self, profile_id, organization_id): return True
    def trade_readiness_satisfied(self, profile_id, organization_id): return True
    def evidence_verified(self, reference): return reference == "E-VERIFIED"
    def market_access_request_exists(self, request_id): return True
    def wim_opportunity_exists(self, opportunity_id): return True
    def procurement_opportunity_exists(self, opportunity_id): return True
    def wim_transaction_exists(self, transaction_id): return True
    def logistics_ready(self, transaction_id): return True


def binding(**changes):
    values = dict(
        brand_id=uuid4(), product_model_id=uuid4(), organization_id=uuid4(),
        wim_product_service_id=uuid4(), procurement_readiness_profile_id=uuid4(),
        trade_readiness_profile_id=uuid4(), evidence_reference="E-VERIFIED",
    )
    values.update(changes)
    return MarketAccessBinding(**values)


def test_market_readiness_uses_authoritative_profiles_and_verified_product():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(binding())
    assert readiness.market_ready is True


def test_unverified_evidence_fails_market_ready():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(binding(evidence_reference="E-NO"))
    assert readiness.evidence_ready is False
    assert readiness.market_ready is False


def test_transaction_requires_wim_opportunity_context():
    with pytest.raises(FashionContractError):
        FashionMarketAccessValidator(Authorities()).evaluate(binding(wim_transaction_id=uuid4()))


def test_transaction_can_reference_logistics_without_creating_finality():
    readiness = FashionMarketAccessValidator(Authorities()).evaluate(
        binding(wim_opportunity_id=uuid4(), wim_transaction_id=uuid4())
    )
    assert readiness.logistics_ready is True


def test_settlement_and_custody_authority_escalation_is_rejected():
    validator = FashionMarketAccessValidator(Authorities())
    with pytest.raises(FashionContractError):
        validator.assert_no_settlement_authority({"settlement_final": True})
    with pytest.raises(FashionContractError):
        validator.assert_no_settlement_authority({"custody_final": True})
