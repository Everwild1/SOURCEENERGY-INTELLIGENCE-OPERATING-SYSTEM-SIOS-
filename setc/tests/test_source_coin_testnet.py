import unittest

from setc.source_coin.testnet import (
    REQUIRED_SCENARIOS,
    ScenarioEvidence,
    TestnetEnvironment,
    TestnetEvidenceManifest,
    TestnetScenario,
    deterministic_synthetic_allocation,
)


class SourceCoinTestnetTests(unittest.TestCase):
    def environment(self):
        return TestnetEnvironment("source-coin-testnet", "synthetic-project", 1000)

    def test_production_material_is_prohibited(self):
        with self.assertRaisesRegex(ValueError, "production material is prohibited"):
            TestnetEnvironment("testnet", "project", 100, production_keys_present=True)

    def test_synthetic_allocation_is_deterministic_and_conserves_supply(self):
        first = deterministic_synthetic_allocation(10, ["org-b", "org-a", "org-c"])
        second = deterministic_synthetic_allocation(10, ["org-c", "org-b", "org-a"])
        self.assertEqual(first, second)
        self.assertEqual(sum(first.values()), 10)

    def test_exit_requires_every_scenario_and_operational_evidence(self):
        manifest = TestnetEvidenceManifest(self.environment())
        for scenario in REQUIRED_SCENARIOS:
            manifest.record(ScenarioEvidence(scenario, True, f"evidence:{scenario.value}"))
        self.assertFalse(manifest.exit_ready())
        manifest.reconciliation_passed = True
        manifest.runbooks_exercised = True
        self.assertTrue(manifest.exit_ready())

    def test_failed_scenario_blocks_exit(self):
        manifest = TestnetEvidenceManifest(
            self.environment(), reconciliation_passed=True, runbooks_exercised=True
        )
        for scenario in REQUIRED_SCENARIOS:
            manifest.record(ScenarioEvidence(scenario, scenario is not TestnetScenario.REPLAY, f"evidence:{scenario.value}"))
        self.assertIn(TestnetScenario.REPLAY, manifest.missing_scenarios())
        self.assertFalse(manifest.exit_ready())

    def test_critical_finding_blocks_exit(self):
        manifest = TestnetEvidenceManifest(
            self.environment(), reconciliation_passed=True, runbooks_exercised=True,
            unresolved_critical_findings=1,
        )
        for scenario in REQUIRED_SCENARIOS:
            manifest.record(ScenarioEvidence(scenario, True, f"evidence:{scenario.value}"))
        self.assertFalse(manifest.exit_ready())


if __name__ == "__main__":
    unittest.main()
