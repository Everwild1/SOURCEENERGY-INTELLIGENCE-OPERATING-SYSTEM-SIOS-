from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.accountability import (
    AccountabilityAssignment, AttestationStatus, DisclosureClassification,
    DisclosureRecord, InstitutionalAttestation,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class AccountabilityTests(unittest.TestCase):
    def test_assignment_validity_must_be_ordered(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            AccountabilityAssignment(sid(1), sid(2), sid(3), "finance", "authority:1", now, now)

    def test_disclosure_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            DisclosureRecord(sid(1), sid(2), "report:1", DisclosureClassification.PUBLIC, datetime.now(timezone.utc), " ")

    def test_attestation_is_not_independent_verification(self) -> None:
        attestation = InstitutionalAttestation(sid(1), sid(2), sid(2), "controls are operating")
        self.assertEqual(attestation.status, AttestationStatus.ASSERTED)
        self.assertFalse(hasattr(attestation, "verified"))
        self.assertFalse(hasattr(attestation, "assured"))

    def test_restricted_disclosure_remains_classified(self) -> None:
        disclosure = DisclosureRecord(
            sid(1), sid(2), "record:restricted", DisclosureClassification.RESTRICTED,
            datetime.now(timezone.utc), "evidence:1", "regulator:1",
        )
        self.assertEqual(disclosure.classification, DisclosureClassification.RESTRICTED)


if __name__ == "__main__":
    unittest.main()
