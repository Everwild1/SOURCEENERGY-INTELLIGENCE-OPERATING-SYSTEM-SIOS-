from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.governance import (
    ApprovalRecord, AuditEvent, GovernanceAuthority, GovernedDecision,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class GovernanceControlTests(unittest.TestCase):
    def test_authority_requires_policy_reference(self) -> None:
        with self.assertRaises(ValueError):
            GovernanceAuthority(sid(1), sid(2), "APPROVER", "capital-readiness", " ")

    def test_authority_dates_are_ordered(self) -> None:
        with self.assertRaises(ValueError):
            GovernanceAuthority(
                sid(1), sid(2), "APPROVER", "procurement", "policy:1",
                effective_from=datetime(2026, 2, 1, tzinfo=timezone.utc),
                effective_to=datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_requester_cannot_self_approve(self) -> None:
        with self.assertRaises(ValueError):
            ApprovalRecord(sid(1), sid(2), sid(3), sid(3), True, sid(4), "evidence:1")

    def test_approval_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            ApprovalRecord(sid(1), sid(2), sid(3), sid(4), True, sid(5), " ")

    def test_decision_evidence_cannot_be_blank(self) -> None:
        with self.assertRaises(ValueError):
            GovernedDecision(sid(1), "organization:1", "VERIFY", sid(2), sid(3), evidence_references=(" ",))

    def test_audit_event_requires_actor_action_and_subject(self) -> None:
        with self.assertRaises(ValueError):
            AuditEvent(sid(1), " ", "APPROVE", "subject:1", datetime.now(timezone.utc))


if __name__ == "__main__":
    unittest.main()
