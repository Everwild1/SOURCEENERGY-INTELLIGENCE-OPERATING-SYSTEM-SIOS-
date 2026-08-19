import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from setc.core import SETCIdentifier
from setc.source_coin.compliance import ComplianceDecision, ComplianceResult
from setc.source_coin.incentives import (
    ContributionRecord,
    ContributionStatus,
    RewardGrant,
    RewardPolicy,
    RewardStatus,
)
from setc.source_coin.settlement import SettlementClass, SettlementInstruction


VALID_ORG_ID = "SETC-OID-0123456789abcdef0123456789abcdef"


class SourceCoinSettlementIncentiveTests(unittest.TestCase):
    def allow_decision(self):
        return ComplianceDecision(
            decision_id=uuid4(),
            subject_type="ORGANIZATION",
            subject_id=VALID_ORG_ID,
            operation_type="SETTLEMENT",
            policy_profile_id=uuid4(),
            policy_version="1.0",
            result=ComplianceResult.ALLOW,
            reason_codes=("ELIGIBLE",),
        )

    def test_settlement_requires_positive_amount(self):
        with self.assertRaises(ValueError):
            SettlementInstruction(
                uuid4(), SettlementClass.INSTITUTIONAL, uuid4(), uuid4(), 0,
                "obl", "policy", self.allow_decision(), "auth", "idem",
                datetime.now(timezone.utc) + timedelta(hours=1),
            )

    def test_expired_settlement_cannot_execute(self):
        instruction = SettlementInstruction(
            uuid4(), SettlementClass.SOURCE_BLOCK, uuid4(), uuid4(), 10,
            "block-event", "policy", self.allow_decision(), "auth", "idem",
            datetime.now(timezone.utc) - timedelta(seconds=1),
        )
        self.assertFalse(instruction.can_execute())

    def test_contribution_cannot_self_validate(self):
        with self.assertRaisesRegex(ValueError, "self-validate"):
            ContributionRecord(
                uuid4(), SETCIdentifier(VALID_ORG_ID),
                "evidence", "principal-a", "principal-a",
            )

    def test_reward_requires_validated_contribution_and_approved_grant(self):
        contribution = ContributionRecord(
            uuid4(), SETCIdentifier(VALID_ORG_ID),
            "evidence", "validator-b", "principal-a", ContributionStatus.VALIDATED,
        )
        policy = RewardPolicy(uuid4(), "1.0", 100)
        grant = RewardGrant(
            uuid4(), contribution.contribution_id,
            SETCIdentifier(VALID_ORG_ID), uuid4(), policy, 50,
            uuid4(), self.allow_decision(), "auth", RewardStatus.APPROVED,
        )
        self.assertTrue(grant.can_execute(contribution))

    def test_reward_policy_cap_is_enforced(self):
        policy = RewardPolicy(uuid4(), "1.0", 10)
        with self.assertRaisesRegex(ValueError, "policy cap"):
            RewardGrant(
                uuid4(), uuid4(), SETCIdentifier(VALID_ORG_ID),
                uuid4(), policy, 11, uuid4(), self.allow_decision(), "auth",
                RewardStatus.APPROVED,
            )


if __name__ == "__main__":
    unittest.main()
