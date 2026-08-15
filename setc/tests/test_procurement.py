import unittest
from datetime import datetime, timezone

from setc.core import SETCIdentifier
from setc.organizations.procurement import (
    MarketAccessReferral, ProcurementOpportunity, ProcurementReadinessProfile,
    ProcurementReadinessState, SupplierQualification,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class ProcurementTests(unittest.TestCase):
    def test_capital_certification_does_not_auto_set_procurement_ready(self) -> None:
        profile = ProcurementReadinessProfile(sid(1), sid(2), capital_readiness_certification_id=sid(3))
        self.assertEqual(profile.state, ProcurementReadinessState.NOT_ASSESSED)

    def test_supplier_cannot_self_qualify(self) -> None:
        with self.assertRaises(ValueError):
            SupplierQualification(sid(1), sid(2), sid(3), True, "evidence:1", sid(3))

    def test_qualification_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            SupplierQualification(sid(1), sid(2), sid(3), True, " ", sid(4))

    def test_opportunity_close_follows_open(self) -> None:
        with self.assertRaises(ValueError):
            ProcurementOpportunity(
                sid(1), sid(2), "Supply contract",
                opens_at=datetime(2026, 8, 2, tzinfo=timezone.utc),
                closes_at=datetime(2026, 8, 1, tzinfo=timezone.utc),
            )

    def test_market_access_referral_is_not_buyer_approval(self) -> None:
        referral = MarketAccessReferral(sid(1), sid(2), sid(3), "Caribbean")
        self.assertFalse(hasattr(referral, "buyer_approved"))
        self.assertFalse(hasattr(referral, "guaranteed_contract"))

    def test_market_access_referral_requires_independence(self) -> None:
        with self.assertRaises(ValueError):
            MarketAccessReferral(sid(1), sid(2), sid(2), "Caribbean")


if __name__ == "__main__":
    unittest.main()
