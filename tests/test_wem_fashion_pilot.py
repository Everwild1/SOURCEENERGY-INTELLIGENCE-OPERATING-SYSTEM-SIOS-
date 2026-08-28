from uuid import uuid4
import pytest
from setc.fashion.pilot import GateOutcome, FashionPilotValidator, PilotGateBinding, PilotPhase
from setc.fashion.service import FashionContractError

class A:
    def organization_active(self,x): return True
    def brand_exists(self,x): return True
    def evidence_verified(self,x): return x=="E-OK"
    def accelerator_gate_approved(self,r,o): return True
    def market_access_ready(self,r,o): return True
    def capital_readiness_satisfied(self,r,o): return True
    def wealth_ecology_verified(self,r,o): return True

def binding(phase,**kw):
    data=dict(organization_id=uuid4(),brand_id=uuid4(),phase=phase,evidence_reference="E-OK",accelerator_transition_reference="A-OK")
    data.update(kw); return PilotGateBinding(**data)

def test_mobilize_approved(): assert FashionPilotValidator(A()).evaluate(binding(PilotPhase.MOBILIZE))==GateOutcome.APPROVED

def test_market_requires_market_access():
    with pytest.raises(FashionContractError): binding(PilotPhase.MARKET_TRADE).validate()

def test_capital_requires_market_and_capital():
    with pytest.raises(FashionContractError): binding(PilotPhase.CAPITAL_MEASURE,market_access_reference="M").validate()

def test_launch_requires_wealth_ecology():
    with pytest.raises(FashionContractError): binding(PilotPhase.LAUNCH_DECISION,market_access_reference="M",capital_readiness_reference="C").validate()

def test_launch_approved_with_all_evidence():
    b=binding(PilotPhase.LAUNCH_DECISION,market_access_reference="M",capital_readiness_reference="C",wealth_ecology_reference="W")
    assert FashionPilotValidator(A()).evaluate(b)==GateOutcome.APPROVED

def test_unverified_evidence_requires_remediation():
    b=binding(PilotPhase.MOBILIZE,evidence_reference="NO")
    assert FashionPilotValidator(A()).evaluate(b)==GateOutcome.REMEDIATION_REQUIRED

@pytest.mark.parametrize("key",["regulatory_approved","certification_final","financing_approved","settlement_final","payment_final","guaranteed_launch","guaranteed_return","wealth_final"])
def test_authority_escalation_rejected(key):
    with pytest.raises(FashionContractError): FashionPilotValidator.assert_no_launch_authority_escalation({key:True})
