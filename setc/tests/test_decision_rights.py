from datetime import datetime, timezone
from decimal import Decimal
import unittest

from setc.core import SETCIdentifier
from setc.organizations.decision_rights import (
    ApprovalThreshold, DecisionDelegation, DecisionEscalation, DecisionOutcome,
    DecisionRecord, QuorumRequirement,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class DecisionRightsTests(unittest.TestCase):
    def test_delegation_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            DecisionDelegation(sid(1), sid(2), sid(3), sid(3), "approve", "auth:1", "evidence:1")

    def test_final_decision_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            DecisionRecord(sid(1), "capital", "request:1", sid(2), DecisionOutcome.APPROVED, datetime.now(timezone.utc))

    def test_threshold_requires_positive_approval_count(self) -> None:
        with self.assertRaises(ValueError):
            ApprovalThreshold(sid(1), "capital", "USD", Decimal("1000"), 0)

    def test_quorum_cannot_exceed_eligible_membership(self) -> None:
        with self.assertRaises(ValueError):
            QuorumRequirement(sid(1), "board", 3, 4)

    def test_escalation_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            DecisionEscalation(sid(1), sid(2), sid(3), sid(3), "threshold exceeded", "evidence:1")

    def test_authorization_is_not_execution(self) -> None:
        decision = DecisionRecord(
            sid(1), "capital", "request:1", sid(2), DecisionOutcome.APPROVED,
            datetime.now(timezone.utc), ("evidence:1",),
        )
        self.assertFalse(hasattr(decision, "executed"))
        self.assertFalse(hasattr(decision, "execution_authorized"))


if __name__ == "__main__":
    unittest.main()
