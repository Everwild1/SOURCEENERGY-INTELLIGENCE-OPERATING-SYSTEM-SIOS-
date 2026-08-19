import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from setc.source_coin.compliance import (
    ComplianceDecision,
    ComplianceResult,
    PolicyProfile,
    evaluate_mandatory_control,
)
from setc.source_coin.treasury import (
    SupplyMode,
    SupplyPolicy,
    TreasuryAuthorization,
    reconcile_supply,
)


class TreasuryInvariantTests(unittest.TestCase):
    def test_capped_policy_requires_cap(self):
        with self.assertRaises(ValueError):
            SupplyPolicy(uuid4(), "v1", SupplyMode.CAPPED, approved=True)

    def test_unapproved_policy_cannot_issue(self):
        policy = SupplyPolicy(uuid4(), "v1", SupplyMode.GOVERNED, approved=False)
        self.assertFalse(policy.permits_supply(0, 100))

    def test_cap_is_enforced(self):
        policy = SupplyPolicy(uuid4(), "v1", SupplyMode.CAPPED, approved=True, max_supply_minor=100)
        self.assertTrue(policy.permits_supply(50, 50))
        self.assertFalse(policy.permits_supply(50, 51))

    def test_separation_of_duties(self):
        with self.assertRaises(ValueError):
            TreasuryAuthorization(uuid4(), uuid4(), "same", "same", 10, "test", approved=True)

    def test_supply_reconciliation(self):
        self.assertEqual(reconcile_supply(100, 30), 70)
        with self.assertRaises(ValueError):
            reconcile_supply(10, 11)


class ComplianceInvariantTests(unittest.TestCase):
    def test_unknown_subject_fails_closed(self):
        profile = PolicyProfile(uuid4(), "v1", "GLOBAL", mandatory_screening=False)
        self.assertEqual(
            evaluate_mandatory_control(profile=profile, subject_known=False, screening_available=True, screening_clear=True),
            ComplianceResult.DENY,
        )

    def test_mandatory_control_outage_fails_closed(self):
        profile = PolicyProfile(uuid4(), "v1", "US", mandatory_screening=True)
        self.assertEqual(
            evaluate_mandatory_control(profile=profile, subject_known=True, screening_available=False, screening_clear=True),
            ComplianceResult.DENY,
        )

    def test_nonclear_screening_requires_review(self):
        profile = PolicyProfile(uuid4(), "v1", "US", mandatory_screening=True)
        self.assertEqual(
            evaluate_mandatory_control(profile=profile, subject_known=True, screening_available=True, screening_clear=False),
            ComplianceResult.REVIEW,
        )

    def test_expired_allow_does_not_permit_execution(self):
        decision = ComplianceDecision(
            uuid4(), "ORGANIZATION", "SETC-OID-001", "TRANSFER", uuid4(), "v1",
            ComplianceResult.ALLOW, ("SCREENED",), valid_until=datetime.now(timezone.utc) - timedelta(seconds=1),
        )
        self.assertFalse(decision.permits_execution())


if __name__ == "__main__":
    unittest.main()
