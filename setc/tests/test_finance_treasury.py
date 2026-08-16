from datetime import datetime, timezone
from decimal import Decimal
import unittest

from setc.core import SETCIdentifier
from setc.organizations.finance_treasury import (
    DisbursementAuthorization, DisbursementState, ReconciliationRecord,
    TreasuryPosition, TreasuryPositionState,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class FinanceTreasuryTests(unittest.TestCase):
    def test_requester_cannot_self_approve_disbursement(self) -> None:
        with self.assertRaises(ValueError):
            DisbursementAuthorization(sid(1), sid(2), sid(3), sid(3), Decimal("10"), "USD", "grant")

    def test_approved_disbursement_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            DisbursementAuthorization(
                sid(1), sid(2), sid(3), sid(4), Decimal("10"), "USD", "grant",
                DisbursementState.APPROVED,
            )

    def test_verified_position_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            TreasuryPosition(
                sid(1), sid(2), Decimal("100"), "USD", datetime.now(timezone.utc),
                TreasuryPositionState.VERIFIED,
            )

    def test_custodian_cannot_independently_reconcile_own_account(self) -> None:
        with self.assertRaises(ValueError):
            ReconciliationRecord(sid(1), sid(2), sid(3), sid(3), "2026-08", Decimal("100"), "USD", "evidence:1")

    def test_reported_balance_is_not_available_funds_assertion(self) -> None:
        position = TreasuryPosition(sid(1), sid(2), Decimal("100"), "USD", datetime.now(timezone.utc))
        self.assertFalse(hasattr(position, "available_balance"))
        self.assertFalse(hasattr(position, "unrestricted_balance"))


if __name__ == "__main__":
    unittest.main()
