from decimal import Decimal
import unittest

from setc.core import SETCIdentifier
from setc.organizations.foundations import (
    AwardState,
    FoundationProfile,
    FundingInstrument,
    GrantAward,
    GrantMilestone,
    ImpactReport,
    PhilanthropicInstrumentType,
)


def oid(value: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{value:032x}")


class FoundationWorkflowTests(unittest.TestCase):
    def test_foundation_requires_mission(self) -> None:
        with self.assertRaises(ValueError):
            FoundationProfile(oid(1), "   ")

    def test_instrument_requires_positive_maximum(self) -> None:
        with self.assertRaises(ValueError):
            FundingInstrument(
                oid(10), oid(1), PhilanthropicInstrumentType.GRANT,
                "Research Grant", maximum_amount=Decimal("0"),
            )

    def test_foundation_cannot_award_itself(self) -> None:
        with self.assertRaises(ValueError):
            GrantAward(oid(20), oid(1), oid(1), oid(10), Decimal("1000"), "USD")

    def test_award_amount_must_be_positive(self) -> None:
        with self.assertRaises(ValueError):
            GrantAward(oid(20), oid(1), oid(2), oid(10), Decimal("-1"), "USD")

    def test_award_is_not_capital_readiness(self) -> None:
        award = GrantAward(
            oid(20), oid(1), oid(2), oid(10), Decimal("1000"), "USD",
            state=AwardState.DISBURSED,
        )
        self.assertEqual(award.state, AwardState.DISBURSED)
        self.assertFalse(hasattr(award, "capital_ready"))

    def test_blank_evidence_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            GrantMilestone(oid(30), oid(20), "Pilot delivery", evidence_reference=" ")

    def test_impact_verification_is_explicit(self) -> None:
        report = ImpactReport(oid(40), oid(20), "jobs_created", Decimal("5"), "jobs")
        self.assertFalse(report.verified)


if __name__ == "__main__":
    unittest.main()
