from datetime import datetime, timezone
from decimal import Decimal
import unittest

from setc.core import SETCIdentifier
from setc.organizations.metrics import (
    ImpactClaim, ImpactClaimStatus, ImpactValidation, MeasurementPeriod,
    MetricDefinition, MetricObservation, MetricValueType, ObservationStatus,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class OrganizationalMetricsTests(unittest.TestCase):
    def test_period_end_must_follow_start(self) -> None:
        with self.assertRaises(ValueError):
            MeasurementPeriod(
                sid(1), datetime(2026, 2, 1, tzinfo=timezone.utc),
                datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_verified_observation_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            MetricObservation(sid(1), sid(2), sid(3), sid(4), Decimal("10"), ObservationStatus.VERIFIED)

    def test_reported_observation_is_not_verified(self) -> None:
        observation = MetricObservation(sid(1), sid(2), sid(3), sid(4), Decimal("10"))
        self.assertEqual(observation.status, ObservationStatus.REPORTED)
        self.assertNotEqual(observation.status, ObservationStatus.VERIFIED)

    def test_validated_claim_requires_metric_support(self) -> None:
        with self.assertRaises(ValueError):
            ImpactClaim(sid(1), sid(2), "jobs created", ImpactClaimStatus.VALIDATED)

    def test_impact_validation_must_be_independent(self) -> None:
        with self.assertRaises(ValueError):
            ImpactValidation(sid(1), sid(2), sid(3), sid(3), True, "evidence:1")

    def test_metric_definition_requires_version(self) -> None:
        with self.assertRaises(ValueError):
            MetricDefinition(sid(1), "Revenue", MetricValueType.CURRENCY, "USD", "Recognized revenue", " ")

    def test_impact_claim_is_not_valuation_or_certification(self) -> None:
        claim = ImpactClaim(sid(1), sid(2), "market access expanded")
        self.assertFalse(hasattr(claim, "valuation"))
        self.assertFalse(hasattr(claim, "certified"))
        self.assertFalse(hasattr(claim, "investment_return"))


if __name__ == "__main__":
    unittest.main()
