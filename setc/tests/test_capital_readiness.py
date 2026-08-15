from datetime import datetime, timedelta, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.capital_readiness import (
    AssessmentDimension, AssessmentFinding, CertificationState,
    ReadinessAssessment, ReadinessCertification, ReadinessPathway,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class CapitalReadinessTests(unittest.TestCase):
    def test_assessment_requires_independent_reviewer(self) -> None:
        with self.assertRaises(ValueError):
            ReadinessAssessment(sid(1), sid(2), sid(3), sid(2))

    def test_dimension_weight_must_be_positive(self) -> None:
        with self.assertRaises(ValueError):
            AssessmentDimension(sid(1), sid(2), "Governance", 0)

    def test_finding_score_is_bounded(self) -> None:
        with self.assertRaises(ValueError):
            AssessmentFinding(sid(1), sid(2), sid(3), 101, "evidence:1")

    def test_finding_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AssessmentFinding(sid(1), sid(2), sid(3), 80, " ")

    def test_certification_requires_independent_issuer(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            ReadinessCertification(
                sid(1), sid(2), sid(3), ReadinessPathway.EQUITY,
                CertificationState.ACTIVE, sid(3), now,
            )

    def test_conditional_certification_requires_conditions(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            ReadinessCertification(
                sid(1), sid(2), sid(3), ReadinessPathway.DEBT,
                CertificationState.CONDITIONAL, sid(4), now,
            )

    def test_expiry_must_follow_issuance(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            ReadinessCertification(
                sid(1), sid(2), sid(3), ReadinessPathway.PROCUREMENT,
                CertificationState.ACTIVE, sid(4), now,
                expires_at=now - timedelta(days=1),
            )

    def test_upstream_program_states_do_not_create_certification(self) -> None:
        assessment = ReadinessAssessment(sid(1), sid(2), sid(3), sid(4))
        self.assertFalse(hasattr(assessment, "incubator_graduated"))
        self.assertFalse(hasattr(assessment, "accelerator_graduated"))
        self.assertFalse(hasattr(assessment, "auto_certified"))


if __name__ == "__main__":
    unittest.main()
