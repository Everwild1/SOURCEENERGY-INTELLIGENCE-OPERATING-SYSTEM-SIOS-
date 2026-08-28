import unittest
from datetime import datetime, timezone

from setc.ecology.domain import AuthorityPosture, EcologyCorrelation, EcologyDomain, EcologyObjectReference
from setc.ecology.gateway import GatewayAction, GatewayRequest, ReceiptStatus
from setc.ecology.gateway_security import GatewayDecision, GatewayPrincipal, GatewayRejection, InMemoryGatewaySecurity


def request(request_id="r1", key="idem-1"):
    subject = EcologyObjectReference(
        domain=EcologyDomain.SOURCE_COIN,
        object_type="settlement_request",
        object_id="synthetic:settlement:1",
        source_authority="SOURCE_COIN",
        posture=AuthorityPosture.REQUEST_ONLY,
    )
    return GatewayRequest(
        request_id=request_id,
        contract_version="1.0",
        target_domain=EcologyDomain.SOURCE_COIN,
        action=GatewayAction.REQUEST_SETTLEMENT,
        correlation=EcologyCorrelation("corr-1", idempotency_key=key),
        subject=subject,
        requested_at=datetime.now(timezone.utc),
    )


def principal(authenticated=True, permitted=True):
    permissions = {EcologyDomain.SOURCE_COIN: frozenset({GatewayAction.REQUEST_SETTLEMENT})} if permitted else {}
    return GatewayPrincipal("principal:test", authenticated, permissions)


class GatewaySecurityTests(unittest.TestCase):
    def test_authenticated_authorized_request_is_only_accepted_for_review(self):
        result = InMemoryGatewaySecurity().evaluate(request(), principal())
        self.assertEqual(result.audit.decision, GatewayDecision.ACCEPTED)
        self.assertEqual(result.receipt.status, ReceiptStatus.ACCEPTED_FOR_REVIEW)
        self.assertFalse(result.receipt.proves_execution)
        self.assertFalse(result.receipt.proves_settlement_finality)
        self.assertFalse(result.audit.proves_execution)
        self.assertFalse(result.audit.confers_source_authority)

    def test_unauthenticated_fails_closed(self):
        result = InMemoryGatewaySecurity().evaluate(request(), principal(authenticated=False))
        self.assertEqual(result.audit.rejection, GatewayRejection.UNAUTHENTICATED)
        self.assertEqual(result.receipt.status, ReceiptStatus.REJECTED)

    def test_unauthorized_fails_closed(self):
        result = InMemoryGatewaySecurity().evaluate(request(), principal(permitted=False))
        self.assertEqual(result.audit.rejection, GatewayRejection.UNAUTHORIZED)

    def test_replay_is_statefully_rejected(self):
        security = InMemoryGatewaySecurity()
        security.evaluate(request(), principal())
        replay = security.evaluate(request(request_id="r2"), principal())
        self.assertEqual(replay.audit.rejection, GatewayRejection.REPLAY)

    def test_rate_limit_is_enforced(self):
        security = InMemoryGatewaySecurity(rate_limit=1)
        security.evaluate(request(), principal())
        limited = security.evaluate(request(request_id="r2", key="idem-2"), principal())
        self.assertEqual(limited.audit.rejection, GatewayRejection.RATE_LIMITED)

    def test_permission_cannot_expand_gateway_allowlist(self):
        p = GatewayPrincipal(
            "principal:test",
            True,
            {EcologyDomain.SOURCE_COIN: frozenset({GatewayAction.REQUEST_CAPITAL_REVIEW})},
        )
        self.assertFalse(p.permits(EcologyDomain.SOURCE_COIN, GatewayAction.REQUEST_CAPITAL_REVIEW))


if __name__ == "__main__":
    unittest.main()
