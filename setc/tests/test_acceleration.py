from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.acceleration import (
    AccelerationParticipation,
    CapitalReadinessReferral,
    EvidenceQuality,
    ReadinessPreparation,
    TractionEvidence,
)


def sid(prefix: str, n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-{prefix}-{n:032x}")


class AccelerationTests(unittest.TestCase):
    def test_completion_cannot_precede_admission(self) -> None:
        with self.assertRaises(ValueError):
            AccelerationParticipation(
                sid("AID", 1), sid("PID", 2), sid("OID", 3),
                admitted_at=datetime(2026, 2, 1, tzinfo=timezone.utc),
                completed_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_traction_defaults_to_self_reported(self) -> None:
        evidence = TractionEvidence(sid("EID", 1), sid("AID", 2), "REVENUE")
        self.assertEqual(evidence.quality, EvidenceQuality.SELF_REPORTED)
        self.assertNotEqual(evidence.quality, EvidenceQuality.VERIFIED)

    def test_blank_traction_type_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TractionEvidence(sid("EID", 1), sid("AID", 2), " ")

    def test_preparation_type_is_governed(self) -> None:
        with self.assertRaises(ValueError):
            ReadinessPreparation(sid("RID", 1), sid("AID", 2), "CAPITAL_CERTIFIED")

    def test_referral_is_not_certification(self) -> None:
        referral = CapitalReadinessReferral(sid("RID", 1), sid("AID", 2))
        self.assertFalse(hasattr(referral, "certified"))
        self.assertFalse(hasattr(referral, "readiness_score"))

    def test_blank_risk_reference_rejected(self) -> None:
        with self.assertRaises(ValueError):
            CapitalReadinessReferral(sid("RID", 1), sid("AID", 2), unresolved_risk=" ")


if __name__ == "__main__":
    unittest.main()
