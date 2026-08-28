import unittest

from setc.ecology.domain import EcologyDomain
from setc.ecology.resilience import (
    DependencyHealth,
    DependencyState,
    RecoveryDecision,
    assess_dependencies,
    source_coin_release_health,
)


class ResilienceTests(unittest.TestCase):
    def test_missing_health_fails_closed(self):
        self.assertEqual(assess_dependencies([]).decision, RecoveryDecision.FAIL_CLOSED)

    def test_unavailable_authority_fails_closed(self):
        assessment = assess_dependencies([
            DependencyHealth(EcologyDomain.WIM, DependencyState.UNAVAILABLE, "incident:wim-1")
        ])
        self.assertEqual(assessment.decision, RecoveryDecision.FAIL_CLOSED)
        self.assertFalse(assessment.confers_source_authority)
        self.assertFalse(assessment.authorizes_financial_execution)

    def test_degraded_dependency_is_read_only(self):
        assessment = assess_dependencies([
            DependencyHealth(EcologyDomain.SETC, DependencyState.HEALTHY, "health:setc"),
            DependencyHealth(EcologyDomain.GSC, DependencyState.DEGRADED, "health:gsc"),
        ])
        self.assertEqual(assessment.decision, RecoveryDecision.READ_ONLY)

    def test_healthy_dependencies_allow_normal_orchestration_only(self):
        assessment = assess_dependencies([
            DependencyHealth(EcologyDomain.SETC, DependencyState.HEALTHY, "health:setc"),
            DependencyHealth(EcologyDomain.WIM, DependencyState.HEALTHY, "health:wim"),
        ])
        self.assertEqual(assessment.decision, RecoveryDecision.NORMAL)
        self.assertFalse(assessment.authorizes_financial_execution)

    def test_source_coin_no_go_cannot_be_bypassed(self):
        assessment = assess_dependencies([
            source_coin_release_health(released=False, evidence_reference="source-coin:release-gate")
        ])
        self.assertEqual(assessment.decision, RecoveryDecision.FAIL_CLOSED)
        self.assertFalse(assessment.bypasses_release_gate)

    def test_health_requires_evidence(self):
        with self.assertRaises(ValueError):
            DependencyHealth(EcologyDomain.WIM, DependencyState.HEALTHY, "   ")


if __name__ == "__main__":
    unittest.main()
