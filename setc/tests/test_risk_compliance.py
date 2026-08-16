from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.risk_compliance import (
    ComplianceAssessment, ComplianceState, RiskAcceptance, RiskRegisterEntry,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class RiskComplianceTests(unittest.TestCase):
    def test_compliance_cannot_be_self_assessed(self) -> None:
        with self.assertRaises(ValueError):
            ComplianceAssessment(sid(1), sid(2), sid(3), sid(3), ComplianceState.COMPLIANT, datetime.now(timezone.utc), ("evidence:1",))

    def test_compliant_assessment_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            ComplianceAssessment(sid(1), sid(2), sid(3), sid(4), ComplianceState.COMPLIANT, datetime.now(timezone.utc))

    def test_risk_owner_cannot_self_accept_residual_risk(self) -> None:
        with self.assertRaises(ValueError):
            RiskAcceptance(sid(1), sid(2), sid(3), sid(3), "within appetite", "evidence:2", datetime.now(timezone.utc))

    def test_risk_identification_is_not_risk_acceptance(self) -> None:
        risk = RiskRegisterEntry(sid(1), sid(2), "Concentration", "Single dependency", sid(3))
        self.assertFalse(hasattr(risk, "accepted_by"))
        self.assertFalse(hasattr(risk, "eliminated"))


if __name__ == "__main__":
    unittest.main()
