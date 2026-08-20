import unittest
from datetime import datetime, timedelta, timezone
from setc.wim.domain import OrganizationBinding, OrganizationEconomicStatus, SetcOrganizationId, VerificationStatus
from setc.wim.opportunity_exchange import Opportunity, OpportunityResponse, OpportunityStatus, OpportunityType, ResponseType

def org(suffix, status=OrganizationEconomicStatus.ACTIVE):
    return OrganizationBinding(SetcOrganizationId("SETC-OID-"+suffix*32), "Org "+suffix, VerificationStatus.VERIFIED, status)

class OpportunityExchangeTests(unittest.TestCase):
    def test_open_verified_opportunity_is_eligible(self):
        o=Opportunity(org("a"),OpportunityType.PROCURE,"Procurement",OpportunityStatus.OPEN,"evidence:1")
        o.require_open()
    def test_open_requires_provenance(self):
        with self.assertRaises(ValueError): Opportunity(org("a"),OpportunityType.BUY,"Buy",OpportunityStatus.OPEN).require_open()
    def test_suspended_originator_fails_closed(self):
        with self.assertRaises(ValueError): Opportunity(org("a",OrganizationEconomicStatus.SUSPENDED),OpportunityType.SELL,"Sell",OpportunityStatus.OPEN,"e:1").require_open()
    def test_expired_window_fails_closed(self):
        now=datetime.now(timezone.utc); o=Opportunity(org("a"),OpportunityType.SOURCE,"Source",OpportunityStatus.OPEN,"e:1",now-timedelta(days=2),now-timedelta(days=1))
        with self.assertRaises(ValueError): o.require_open(now)
    def test_originator_cannot_self_respond(self):
        a=org("a"); o=Opportunity(a,OpportunityType.PARTNER,"Partner",OpportunityStatus.OPEN,"e:1")
        with self.assertRaises(ValueError): OpportunityResponse(o,a,ResponseType.PARTNERSHIP,"r:1").require_eligible()
    def test_verified_distinct_responder_is_eligible(self):
        o=Opportunity(org("a"),OpportunityType.EXPORT,"Export",OpportunityStatus.OPEN,"e:1")
        OpportunityResponse(o,org("b"),ResponseType.PROPOSAL,"r:1").require_eligible()
    def test_opportunity_and_response_are_non_binding(self):
        o=Opportunity(org("a"),OpportunityType.INVEST,"Invest",OpportunityStatus.OPEN,"e:1")
        r=OpportunityResponse(o,org("b"),ResponseType.INTEREST,"r:1")
        self.assertFalse(o.creates_transaction_or_investment_authorization); self.assertFalse(r.creates_award_or_settlement)

if __name__=="__main__": unittest.main()
