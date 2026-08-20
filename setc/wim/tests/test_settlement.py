import unittest
from decimal import Decimal
from setc.wim.settlement import AuthoritativeSettlementConfirmation, SettlementRail, SettlementRequest, SettlementStatus, SettlementCorrection

class SettlementTests(unittest.TestCase):
    def request(self,rail=SettlementRail.SOURCE_COIN):
        return SettlementRequest("txn:1",rail,"req:1","idem:1","corr:1",Decimal("10.00"),"USD","compliance:1")
    def test_wim_request_cannot_mutate_source_coin_or_confer_finality(self):
        r=self.request(); self.assertFalse(r.can_mutate_source_coin_ledger); self.assertFalse(r.confers_settlement_finality)
    def test_negative_amount_fails_closed(self):
        with self.assertRaises(ValueError): SettlementRequest("txn","fiat_external","req","idem","corr",Decimal("-1"))
    def test_source_coin_reference_requires_authoritative_namespace(self):
        c=AuthoritativeSettlementConfirmation(SettlementRail.SOURCE_COIN,"external-1",SettlementStatus.CONFIRMED)
        with self.assertRaises(ValueError): c.require_final()
    def test_source_coin_authoritative_confirmation_can_be_final(self):
        AuthoritativeSettlementConfirmation(SettlementRail.SOURCE_COIN,"SC-SETTLEMENT-123",SettlementStatus.CONFIRMED).require_final()
    def test_pending_reference_is_not_final(self):
        c=AuthoritativeSettlementConfirmation(SettlementRail.FIAT_EXTERNAL,"bank-ref",SettlementStatus.PENDING)
        with self.assertRaises(ValueError): c.require_final()
    def test_rails_remain_distinguishable(self):
        self.assertNotEqual(SettlementRail.FIAT_EXTERNAL,SettlementRail.SOURCE_COIN)
    def test_idempotency_key_is_required(self):
        with self.assertRaises(ValueError): SettlementRequest("txn",SettlementRail.SOURCE_COIN,"req","","corr")
    def test_correction_is_append_only_compensation(self):
        c=SettlementCorrection({"status":"failed"},{"status":"requested"},"retry after external correction","e:1")
        self.assertTrue(c.is_compensating_append_only_evidence)

if __name__=="__main__": unittest.main()
