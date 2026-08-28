from uuid import uuid4
import pytest
from setc.fashion.service import FashionContractError
from setc.fashion.wealth_ecology import WealthCapital, WealthStage, WealthEcologyBinding, FashionWealthEcologyValidator

class A:
    def evidence_verified(self,x): return True
    def impact_metric_verified(self,x): return True
    def commercial_outcome_verified(self,x,o): return True
    def impact_observation_verified(self,x,o): return True
    def wealth_yield_verified(self,x,o): return True
    def investment_asset_verified(self,x,o): return True
    def seae_impact_link_exists(self,x): return True
    def revenue_event_exists(self,x): return True

def test_seven_capital_classes(): assert len(WealthCapital)==7
def test_seven_value_stages(): assert len(WealthStage)==7

def test_activity_measurement_uses_external_authorities():
    b=WealthEcologyBinding(uuid4(),WealthCapital.ENTERPRISE,WealthStage.VALUE_CREATED,"ev",cruds_impact_metric_id=uuid4(),rw_commercial_outcome_id=uuid4())
    FashionWealthEcologyValidator(A()).validate_measurement(b)

def test_wealth_stage_requires_authoritative_asset_or_yield():
    b=WealthEcologyBinding(uuid4(),WealthCapital.GENERATIONAL,WealthStage.WEALTH_PRODUCED,"ev")
    with pytest.raises(FashionContractError): FashionWealthEcologyValidator(A()).validate_measurement(b)

def test_wealth_stage_with_verified_yield():
    b=WealthEcologyBinding(uuid4(),WealthCapital.GENERATIONAL,WealthStage.WEALTH_REINVESTED,"ev",rw_wealth_yield_record_id=uuid4())
    FashionWealthEcologyValidator(A()).validate_measurement(b)

def test_rejects_metric_inflation():
    with pytest.raises(FashionContractError): FashionWealthEcologyValidator.assert_no_metric_inflation({"guaranteed_wealth":True})
