from uuid import uuid4
import pytest
from setc.fashion.circular import CircularEventBinding,CircularStage,FashionCircularValidator
from setc.fashion.service import FashionContractError
class A:
 def product_instance_exists(self,x): return True
 def organization_active(self,x): return True
 def evidence_verified(self,x): return x=='VERIFIED'
 def wim_transaction_exists(self,x): return True
 def delivery_evidence_verified(self,x): return True
 def revenue_event_exists(self,x): return True
 def royalty_allocation_exists(self,x): return True

def event(**k):
 v=dict(product_instance_id=uuid4(),stage=CircularStage.REPAIR,actor_organization_oid='SEG-ORG',evidence_reference='VERIFIED');v.update(k);return CircularEventBinding(**v)
def test_verified_event_passes(): FashionCircularValidator(A()).validate_event(event())
def test_unverified_evidence_fails():
 with pytest.raises(FashionContractError): FashionCircularValidator(A()).validate_event(event(evidence_reference='NO'))
def test_resale_requires_transaction():
 with pytest.raises(FashionContractError): FashionCircularValidator(A()).validate_event(event(stage=CircularStage.RESELL))
def test_resale_with_transaction_passes(): FashionCircularValidator(A()).validate_event(event(stage=CircularStage.RESELL,wim_transaction_id=uuid4()))
def test_history_is_append_only():
 FashionCircularValidator.assert_append_only('insert')
 with pytest.raises(FashionContractError): FashionCircularValidator.assert_append_only('delete')
def test_external_authority_escalation_rejected():
 with pytest.raises(FashionContractError): FashionCircularValidator.assert_no_authority_escalation({'ownership_transferred':True})
