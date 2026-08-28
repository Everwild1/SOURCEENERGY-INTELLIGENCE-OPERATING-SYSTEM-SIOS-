from uuid import uuid4

import pytest

from setc.fashion.capital import CapitalGate, FashionCapitalBinding, FashionCapitalValidator
from setc.fashion.service import FashionContractError


class Authorities:
    def fashion_brand_exists(self, brand_id): return True
    def capital_readiness_satisfied(self, profile_id, organization_id): return True
    def evidence_verified(self, reference): return reference == "E-VERIFIED"
    def capital_request_exists(self, request_id, organization_id): return True
    def capital_referral_exists(self, referral_id, request_id): return True
    def capital_event_verified(self, event_id, organization_id): return True
    def wealth_yield_verified(self, record_id, organization_id): return True
    def investment_asset_verified(self, asset_id, organization_id): return True


def binding(**changes):
    values = dict(
        organization_id=uuid4(), brand_id=uuid4(), readiness_profile_id=uuid4(),
        gate=CapitalGate.C0_FORMATION, evidence_reference="E-VERIFIED",
    )
    values.update(changes)
    return FashionCapitalBinding(**values)


def test_c0_readiness_consumes_rw_readiness_and_verified_evidence():
    decision = FashionCapitalValidator(Authorities()).evaluate(binding())
    assert decision.ready is True


def test_unverified_evidence_blocks_gate_readiness():
    decision = FashionCapitalValidator(Authorities()).evaluate(binding(evidence_reference="E-NO"))
    assert decision.ready is False


def test_referral_requires_request_context():
    with pytest.raises(FashionContractError):
        FashionCapitalValidator(Authorities()).evaluate(binding(capital_referral_id=uuid4()))


def test_c5_requires_authoritative_wealth_or_asset_evidence():
    with pytest.raises(FashionContractError):
        FashionCapitalValidator(Authorities()).evaluate(binding(gate=CapitalGate.C5_WEALTH_CONVERSION))
    decision = FashionCapitalValidator(Authorities()).evaluate(
        binding(gate=CapitalGate.C5_WEALTH_CONVERSION, wealth_yield_record_id=uuid4())
    )
    assert decision.ready is True


def test_financing_and_investment_authority_escalation_is_rejected():
    validator = FashionCapitalValidator(Authorities())
    for key in ("financing_approved", "investment_approved", "securities_status", "settlement_final", "guaranteed_return"):
        with pytest.raises(FashionContractError):
            validator.assert_no_financial_authority({key: True})
