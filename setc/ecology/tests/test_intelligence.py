import unittest

from setc.ecology.intelligence import (
    IntelligenceInput,
    MeasurementPosture,
    authority_concentration,
    evidence_coverage,
    regenerative_ratio,
    value_throughput,
)


class WealthEcologyIntelligenceTests(unittest.TestCase):
    def test_throughput_is_deterministic_and_derived(self):
        result = value_throughput((
            IntelligenceInput("a", 25.0, "wim"),
            IntelligenceInput("b", 75.0, "capitalization"),
        ))
        self.assertEqual(result.value, 100.0)
        self.assertTrue(result.is_derived_projection)
        self.assertFalse(result.confers_settlement_finality)
        self.assertFalse(result.confers_ownership)
        self.assertFalse(result.confers_approval)

    def test_verified_requires_external_or_source_verification_authority(self):
        with self.assertRaises(ValueError):
            IntelligenceInput("a", 1.0, "wim", MeasurementPosture.VERIFIED)

    def test_aggregation_does_not_self_promote_to_verified(self):
        result = value_throughput((
            IntelligenceInput("a", 1.0, "wim", MeasurementPosture.VERIFIED, 1.0, "wim-verifier"),
            IntelligenceInput("b", 1.0, "hei", MeasurementPosture.OBSERVED, 0.8),
        ))
        self.assertEqual(result.posture, MeasurementPosture.OBSERVED)

    def test_all_verified_inputs_may_retain_verified_posture(self):
        result = value_throughput((
            IntelligenceInput("a", 1.0, "wim", MeasurementPosture.VERIFIED, 1.0, "wim-verifier"),
            IntelligenceInput("b", 2.0, "hei", MeasurementPosture.VERIFIED, 1.0, "hei-verifier"),
        ))
        self.assertEqual(result.posture, MeasurementPosture.VERIFIED)

    def test_regenerative_ratio(self):
        self.assertEqual(regenerative_ratio(20, 100).value, 0.2)
        self.assertEqual(regenerative_ratio(20, 0).value, 0.0)

    def test_authority_concentration_hhi(self):
        result = authority_concentration((
            IntelligenceInput("a", 50, "wim"),
            IntelligenceInput("b", 50, "hei"),
        ))
        self.assertAlmostEqual(result.value, 0.5)

    def test_evidence_coverage(self):
        result = evidence_coverage((
            IntelligenceInput("a", 1, "wim", confidence=0.7),
            IntelligenceInput("b", 1, "hei"),
        ))
        self.assertEqual(result.value, 0.5)

    def test_negative_values_fail_closed(self):
        with self.assertRaises(ValueError):
            IntelligenceInput("a", -1, "wim")


if __name__ == "__main__":
    unittest.main()
