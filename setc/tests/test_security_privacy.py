from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.security_privacy import (
    AccessDecision, ConsentRecord, DataAssetControl, DataClassification,
    LegalBasis, ProcessingAuthorization,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class SecurityPrivacyTests(unittest.TestCase):
    def test_access_requester_cannot_self_approve(self) -> None:
        with self.assertRaises(ValueError):
            AccessDecision(sid(1), "record:1", sid(2), sid(2), "research", True, "evidence:1")

    def test_processing_authorization_requires_purpose(self) -> None:
        with self.assertRaises(ValueError):
            ProcessingAuthorization(sid(1), "record:1", sid(2), " ", LegalBasis.CONTRACT, "policy:1")

    def test_processing_validity_is_ordered(self) -> None:
        with self.assertRaises(ValueError):
            ProcessingAuthorization(
                sid(1), "record:1", sid(2), "research", LegalBasis.CONSENT, "consent:1",
                datetime(2026, 2, 1, tzinfo=timezone.utc), datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_consent_withdrawal_cannot_precede_grant(self) -> None:
        with self.assertRaises(ValueError):
            ConsentRecord(
                sid(1), "person:1", sid(2), "analytics", "evidence:1",
                datetime(2026, 2, 1, tzinfo=timezone.utc), datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_restricted_asset_does_not_imply_access(self) -> None:
        control = DataAssetControl(sid(1), "record:1", DataClassification.RESTRICTED, sid(2))
        self.assertFalse(hasattr(control, "access_granted"))
        self.assertFalse(hasattr(control, "consent"))

    def test_consent_is_not_blanket_authorization(self) -> None:
        consent = ConsentRecord(
            sid(1), "person:1", sid(2), "specific-purpose", "evidence:1", datetime.now(timezone.utc)
        )
        self.assertEqual(consent.purpose, "specific-purpose")
        self.assertFalse(hasattr(consent, "all_purposes"))


if __name__ == "__main__":
    unittest.main()
