import unittest

from setc.ecology.readiness import (
    ControlSeverity, ReadinessControl, ReleaseDisposition,
    current_ecology_assessment, evaluate_readiness,
)


class EcologyReadinessTests(unittest.TestCase):
    def control(self, cid, ok, conditional=False, severity=ControlSeverity.MANDATORY):
        return ReadinessControl(cid, cid, severity, ok, ("evidence",) if ok else (), conditional)

    def test_empty_evidence_is_no_go(self):
        self.assertEqual(ReleaseDisposition.NO_GO, evaluate_readiness(()).disposition)

    def test_unwaivable_mandatory_failure_is_no_go(self):
        result = evaluate_readiness((self.control("critical", False),))
        self.assertEqual(ReleaseDisposition.NO_GO, result.disposition)

    def test_bounded_missing_dependencies_can_be_conditional_go(self):
        result = evaluate_readiness((self.control("engineering", True), self.control("external", False, True)))
        self.assertEqual(ReleaseDisposition.CONDITIONAL_GO, result.disposition)
        self.assertIn("no_source_coin_production_effects", result.conditional_constraints)

    def test_go_requires_every_mandatory_control(self):
        result = evaluate_readiness((self.control("a", True), self.control("b", True), self.control("advice", False, severity=ControlSeverity.ADVISORY)))
        self.assertEqual(ReleaseDisposition.GO, result.disposition)

    def test_satisfied_control_requires_evidence(self):
        with self.assertRaises(ValueError):
            ReadinessControl("x", "x", ControlSeverity.MANDATORY, True)

    def test_release_assessment_never_confers_execution_or_finality(self):
        result = evaluate_readiness((self.control("a", True),))
        self.assertFalse(result.authorizes_financial_execution)
        self.assertFalse(result.confers_settlement_finality)

    def test_current_posture_is_conditional_not_full_go(self):
        result = current_ecology_assessment()
        self.assertEqual(ReleaseDisposition.CONDITIONAL_GO, result.disposition)
        self.assertFalse(result.authorizes_financial_execution)


if __name__ == "__main__":
    unittest.main()
