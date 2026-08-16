from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.records_governance import (
    AuthenticityStatus, InstitutionalRecord, LegalHold, RecordAuthenticityVerification,
    RecordClassification, RecordDispositionAuthorization, RecordStatus, RecordVersion,
    RetentionSchedule,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class RecordsGovernanceTests(unittest.TestCase):
    def test_record_requires_reference_and_title(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalRecord(sid(1), sid(2), "", "Title", RecordClassification.INTERNAL, sid(3))

    def test_version_cannot_supersede_itself(self) -> None:
        with self.assertRaises(ValueError):
            RecordVersion(sid(1), sid(2), "1.0", "content:1", datetime.now(timezone.utc), sid(1))

    def test_retention_period_cannot_be_negative(self) -> None:
        with self.assertRaises(ValueError):
            RetentionSchedule(sid(1), sid(2), "financial", "law", -1)

    def test_legal_hold_release_cannot_precede_imposition(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            LegalHold(sid(1), sid(2), "court:1", "litigation", now, datetime.min.replace(tzinfo=timezone.utc))

    def test_disposition_requires_independent_approval(self) -> None:
        with self.assertRaises(ValueError):
            RecordDispositionAuthorization(sid(1), sid(2), sid(3), sid(3), "destroy", "policy:1", "evidence:1")

    def test_verified_authenticity_requires_independent_evidence(self) -> None:
        with self.assertRaises(ValueError):
            RecordAuthenticityVerification(sid(1), sid(2), sid(3), sid(4), AuthenticityStatus.VERIFIED)

    def test_record_existence_does_not_imply_authenticity_or_access(self) -> None:
        record = InstitutionalRecord(
            sid(1), sid(2), "record:1", "Board Minutes", RecordClassification.CONFIDENTIAL,
            sid(3), RecordStatus.CURRENT,
        )
        self.assertFalse(hasattr(record, "authentic"))
        self.assertFalse(hasattr(record, "access_granted"))
        self.assertFalse(hasattr(record, "disposable"))


if __name__ == "__main__":
    unittest.main()
