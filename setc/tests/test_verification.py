from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.verification import (
    Credential, EvidenceRecord, VerificationRecord, VerificationStatus,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class VerificationTests(unittest.TestCase):
    def test_organization_cannot_self_verify(self) -> None:
        with self.assertRaises(ValueError):
            VerificationRecord(sid(1), sid(2), sid(2), sid(3), "LEGAL_EXISTENCE")

    def test_verified_claim_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            VerificationRecord(
                sid(1), sid(2), sid(3), sid(4), "LEGAL_EXISTENCE",
                status=VerificationStatus.VERIFIED,
            )

    def test_assertion_is_not_verification(self) -> None:
        record = VerificationRecord(sid(1), sid(2), sid(3), sid(4), "LEGAL_EXISTENCE")
        self.assertEqual(record.status, VerificationStatus.ASSERTED)
        self.assertNotEqual(record.status, VerificationStatus.VERIFIED)

    def test_verification_validity_is_ordered(self) -> None:
        with self.assertRaises(ValueError):
            VerificationRecord(
                sid(1), sid(2), sid(3), sid(4), "LEGAL_EXISTENCE",
                valid_from=datetime(2026, 2, 1, tzinfo=timezone.utc),
                valid_until=datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_credential_issuer_is_independent(self) -> None:
        with self.assertRaises(ValueError):
            Credential(sid(1), sid(2), sid(2), "ACCREDITATION")

    def test_credential_expiry_follows_issuance(self) -> None:
        with self.assertRaises(ValueError):
            Credential(
                sid(1), sid(2), sid(3), "ACCREDITATION",
                issued_at=datetime(2026, 2, 1, tzinfo=timezone.utc),
                expires_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_evidence_requires_provenance(self) -> None:
        with self.assertRaises(ValueError):
            EvidenceRecord(sid(1), "subject:1", " ")


if __name__ == "__main__":
    unittest.main()
