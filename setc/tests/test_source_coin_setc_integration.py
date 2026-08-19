import unittest
from uuid import uuid4

from setc.core import SETCIdentifier
from setc.source_coin.integration import (
    ChainAnchorReference,
    EconomicRequestType,
    IntegrationDecision,
    SourceBlockEconomicRequest,
    validate_source_block_request,
)


ORG_ID = SETCIdentifier("SETC-OID-0123456789abcdef0123456789abcdef")


class SourceCoinSETCIntegrationTests(unittest.TestCase):
    def settlement_request(self):
        return SourceBlockEconomicRequest(
            request_id=uuid4(),
            source_block_id="research-block-001",
            organization_id=ORG_ID,
            request_type=EconomicRequestType.SETTLEMENT,
            provenance_ref="evidence://source-block/001",
            correlation_id="corr-001",
            causation_id="event-001",
            idempotency_key="source-block-settlement-001",
            obligation_ref="obligation-001",
        )

    def test_source_block_never_has_direct_ledger_authority(self):
        request = self.settlement_request()
        self.assertFalse(request.may_mutate_ledger)
        self.assertEqual(validate_source_block_request(request), IntegrationDecision.ACCEPTED)

    def test_settlement_request_requires_obligation(self):
        with self.assertRaisesRegex(ValueError, "obligation_ref"):
            SourceBlockEconomicRequest(
                request_id=uuid4(),
                source_block_id="research-block-002",
                organization_id=ORG_ID,
                request_type=EconomicRequestType.SETTLEMENT,
                provenance_ref="evidence://source-block/002",
                correlation_id="corr-002",
                causation_id="event-002",
                idempotency_key="source-block-settlement-002",
            )

    def test_reward_request_requires_contribution(self):
        with self.assertRaisesRegex(ValueError, "contribution_ref"):
            SourceBlockEconomicRequest(
                request_id=uuid4(),
                source_block_id="research-block-003",
                organization_id=ORG_ID,
                request_type=EconomicRequestType.REWARD,
                provenance_ref="evidence://source-block/003",
                correlation_id="corr-003",
                causation_id="event-003",
                idempotency_key="source-block-reward-003",
            )

    def test_chain_anchor_is_evidence_not_authority(self):
        anchor = ChainAnchorReference("foundation-sidechain", "0xabc", "proof://abc")
        request = SourceBlockEconomicRequest(
            request_id=uuid4(),
            source_block_id="research-block-004",
            organization_id=ORG_ID,
            request_type=EconomicRequestType.SETTLEMENT,
            provenance_ref="evidence://source-block/004",
            correlation_id="corr-004",
            causation_id="event-004",
            idempotency_key="source-block-settlement-004",
            obligation_ref="obligation-004",
            chain_anchor=anchor,
        )
        self.assertFalse(request.may_mutate_ledger)


if __name__ == "__main__":
    unittest.main()
