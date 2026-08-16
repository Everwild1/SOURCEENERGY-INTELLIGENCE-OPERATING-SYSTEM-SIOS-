from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.agreements_obligations import (
    AgreementBreach, AgreementObligation, AgreementState, BreachState,
    InstitutionalAgreement, ObligationState, TerminationAuthorization,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class AgreementsObligationsTests(unittest.TestCase):
    def test_agreement_requires_distinct_counterparties(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalAgreement(sid(1), sid(2), sid(2), "agreement:1", "MOU", datetime.now(timezone.utc))

    def test_active_agreement_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalAgreement(
                sid(1), sid(2), sid(3), "agreement:1", "MOU",
                datetime.now(timezone.utc), state=AgreementState.ACTIVE,
            )

    def test_satisfied_obligation_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AgreementObligation(sid(1), sid(2), sid(3), sid(4), "deliver report", state=ObligationState.SATISFIED)

    def test_confirmed_breach_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AgreementBreach(sid(1), sid(2), None, sid(3), sid(4), "missed delivery", BreachState.CONFIRMED)

    def test_termination_requester_cannot_self_approve(self) -> None:
        with self.assertRaises(ValueError):
            TerminationAuthorization(
                sid(1), sid(2), sid(3), sid(3), "material breach", "authority:1",
                "evidence:1", datetime.now(timezone.utc),
            )

    def test_agreement_does_not_imply_obligation_satisfaction_or_termination_authority(self) -> None:
        agreement = InstitutionalAgreement(
            sid(1), sid(2), sid(3), "agreement:1", "MOU", datetime.now(timezone.utc)
        )
        self.assertFalse(hasattr(agreement, "obligations_satisfied"))
        self.assertFalse(hasattr(agreement, "termination_authorized"))
        self.assertFalse(hasattr(agreement, "breach_confirmed"))


if __name__ == "__main__":
    unittest.main()
