from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.resilience import (
    ContinuityPlan, ExerciseOutcome, RecoveryObjective, ResilienceExercise,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class ResilienceTests(unittest.TestCase):
    def test_recovery_time_must_be_positive(self) -> None:
        with self.assertRaises(ValueError):
            RecoveryObjective(sid(1), sid(2), "payments", 0)

    def test_successful_exercise_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            ResilienceExercise(
                sid(1), sid(2), sid(3), "regional outage",
                datetime.now(timezone.utc), ExerciseOutcome.MET,
            )

    def test_draft_plan_is_not_demonstrated_resilience(self) -> None:
        plan = ContinuityPlan(sid(1), sid(2), "Enterprise Continuity", "1.0")
        self.assertFalse(hasattr(plan, "resilient"))
        self.assertFalse(hasattr(plan, "certified"))

    def test_exercise_with_evidence_can_record_success(self) -> None:
        exercise = ResilienceExercise(
            sid(1), sid(2), sid(3), "service outage",
            datetime.now(timezone.utc), ExerciseOutcome.MET, ("evidence:test",),
        )
        self.assertEqual(exercise.outcome, ExerciseOutcome.MET)


if __name__ == "__main__":
    unittest.main()
