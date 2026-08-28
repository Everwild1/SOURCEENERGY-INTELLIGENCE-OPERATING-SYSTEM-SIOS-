import unittest

from setc.ecology.pilot import CANONICAL_STAGES, run_synthetic_pilot


class EcologySyntheticPilotTests(unittest.TestCase):
    def test_closed_loop_pilot_passes_without_production_effects(self):
        report = run_synthetic_pilot()
        self.assertTrue(report.passed)
        self.assertTrue(report.closed_loop)
        self.assertFalse(report.production_effects)
        self.assertEqual(tuple(stage.stage for stage in report.stages), CANONICAL_STAGES)

    def test_required_failure_injections_are_proven(self):
        report = run_synthetic_pilot("failure-proof")
        expected = {
            "replayed_material_request_blocked",
            "missing_idempotency_blocked",
            "unauthorized_target_action_blocked",
            "source_coin_finality_not_asserted",
            "authority_escalation_not_permitted",
            "allocation_concentration_blocked",
        }
        self.assertEqual(expected, set(report.failures_injected))

    def test_loop_returns_to_new_research_cycle(self):
        report = run_synthetic_pilot("loop-proof")
        self.assertEqual("reinvestment", report.stages[-2].stage)
        self.assertEqual("next_research_cycle", report.stages[-1].stage)

    def test_blank_pilot_id_fails_closed(self):
        with self.assertRaises(ValueError):
            run_synthetic_pilot(" ")


if __name__ == "__main__":
    unittest.main()
