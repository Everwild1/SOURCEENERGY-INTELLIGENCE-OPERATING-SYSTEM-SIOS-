import unittest
from uuid import UUID
from setc.wim.domain import OrganizationBinding,OrganizationEconomicStatus,SetcOrganizationId,VerificationStatus
from setc.wim.organization_market_graph import TradeCorridor
from setc.wim.trade_supply_chain import ComplianceCheckpoint,ComplianceStatus,LogisticsReference,Trade,TradeCorrection,TradeStatus

def org(ch,status=OrganizationEconomicStatus.ACTIVE): return OrganizationBinding(SetcOrganizationId("SETC-OID-"+ch*32),"Org "+ch,VerificationStatus.VERIFIED,status)
def corridor(status="active"): return TradeCorridor(UUID("00000000-0000-0000-0000-000000000003"),"Corridor",UUID("00000000-0000-0000-0000-000000000001"),UUID("00000000-0000-0000-0000-000000000002"),status)
class TradeTests(unittest.TestCase):
 def test_approved_trade_with_clear_compliance(self): Trade(org("a"),org("b"),corridor(),TradeStatus.APPROVED,"compliance:1").require_progression((ComplianceCheckpoint("customs",ComplianceStatus.PASSED,"e:1"),))
 def test_failed_compliance_stops_trade(self):
  with self.assertRaises(ValueError): Trade(org("a"),org("b"),corridor(),TradeStatus.APPROVED,"c:1").require_progression((ComplianceCheckpoint("customs",ComplianceStatus.FAILED),))
 def test_restricted_corridor_stops_trade(self):
  with self.assertRaises(ValueError): Trade(org("a"),org("b"),corridor("restricted")).require_progression()
 def test_in_transit_requires_logistics(self):
  with self.assertRaises(ValueError): Trade(org("a"),org("b"),corridor(),TradeStatus.IN_TRANSIT,"c:1").require_progression()
 def test_reconciliation_requires_settlement_authority_status(self):
  with self.assertRaises(ValueError): Trade(org("a"),org("b"),corridor(),TradeStatus.RECONCILED,"c:1",settlement_status="requested").require_progression()
 def test_trade_never_creates_settlement_finality(self): self.assertFalse(Trade(org("a"),org("b"),corridor()).creates_settlement_finality)
 def test_cash_logistics_is_reference_only(self): self.assertFalse(LogisticsReference("cash_logistics","ext:1").confers_banking_or_custody_authority)
 def test_corrections_are_append_only_evidence(self): self.assertTrue(TradeCorrection({"s":"old"},{"s":"new"},"operator correction","e:1").is_append_only_evidence)
if __name__=="__main__": unittest.main()
