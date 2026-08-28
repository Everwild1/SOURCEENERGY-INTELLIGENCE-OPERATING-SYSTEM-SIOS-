import unittest
from datetime import datetime, timezone

from setc.ecology.domain import AuthorityPosture, EcologyCorrelation, EcologyDomain, EcologyObjectReference
from setc.ecology.gateway import GatewayAction, GatewayReceipt, GatewayRequest, ReceiptStatus, allowed_actions


class EcologyGatewayTests(unittest.TestCase):
    def ref(self, domain=EcologyDomain.WIM):
        return EcologyObjectReference(domain=domain, object_type="case", object_id="123", source_authority=domain.value, posture=AuthorityPosture.REFERENCE_ONLY)

    def correlation(self, idem="idem-1"):
        return EcologyCorrelation(correlation_id="corr-1", causation_id="cause-1", idempotency_key=idem)

    def test_material_request_requires_idempotency(self):
        with self.assertRaises(ValueError):
            GatewayRequest("r", "1.0", EcologyDomain.WIM, GatewayAction.REQUEST_MARKET_WORKFLOW, self.correlation(None), self.ref())

    def test_action_allowlist_fails_closed(self):
        with self.assertRaises(ValueError):
            GatewayRequest("r", "1.0", EcologyDomain.SOURCE_COIN, GatewayAction.REQUEST_MARKET_WORKFLOW, self.correlation(), self.ref(EcologyDomain.SOURCE_COIN))

    def test_source_coin_request_cannot_bypass_release_gate_or_assert_finality(self):
        request = GatewayRequest("r", "1.0", EcologyDomain.SOURCE_COIN, GatewayAction.REQUEST_SETTLEMENT, self.correlation(), self.ref(EcologyDomain.SOURCE_COIN), requested_at=datetime.now(timezone.utc))
        self.assertFalse(request.is_execution_instruction)
        self.assertFalse(request.confers_source_authority)
        self.assertFalse(request.confers_settlement_finality)
        self.assertFalse(request.may_bypass_release_gate)

    def test_receipt_is_not_execution_or_finality_proof(self):
        receipt = GatewayReceipt("receipt", "request", EcologyDomain.WIM, ReceiptStatus.ACCEPTED_FOR_REVIEW, self.ref(EcologyDomain.WIM))
        self.assertFalse(receipt.proves_execution)
        self.assertFalse(receipt.proves_settlement_finality)

    def test_receipt_result_reference_must_match_target(self):
        with self.assertRaises(ValueError):
            GatewayReceipt("receipt", "request", EcologyDomain.WIM, ReceiptStatus.RECEIVED, self.ref(EcologyDomain.HEI))

    def test_external_authority_has_no_material_action(self):
        self.assertEqual(frozenset({GatewayAction.REGISTER_REFERENCE}), allowed_actions(EcologyDomain.EXTERNAL_AUTHORITY))


if __name__ == "__main__":
    unittest.main()
