from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.interoperability import (
    DataSharingAuthorization, EvidencePackage, ExchangeDirection, ImportTrustStatus,
    InstitutionalExchange,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class InteroperabilityTests(unittest.TestCase):
    def test_authorization_requires_distinct_organizations(self) -> None:
        with self.assertRaises(ValueError):
            DataSharingAuthorization(sid(1), sid(2), sid(2), ExchangeDirection.OUTBOUND, "metrics", "evidence:1")

    def test_exchange_requires_distinct_systems(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalExchange(sid(1), sid(2), sid(3), ExchangeDirection.INBOUND, source_system="x", destination_system="x")

    def test_import_defaults_to_imported_not_verified(self) -> None:
        package = EvidencePackage(sid(1), sid(2), "authority:external")
        self.assertEqual(package.trust_status, ImportTrustStatus.IMPORTED)

    def test_setc_verified_import_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            EvidencePackage(sid(1), sid(2), "authority:external", trust_status=ImportTrustStatus.SETC_VERIFIED)

    def test_import_does_not_create_credential_or_certification(self) -> None:
        package = EvidencePackage(sid(1), sid(2), "authority:external", record_references=("record:1",))
        self.assertFalse(hasattr(package, "credential"))
        self.assertFalse(hasattr(package, "certification"))
        self.assertFalse(hasattr(package, "endorsement"))


if __name__ == "__main__":
    unittest.main()
