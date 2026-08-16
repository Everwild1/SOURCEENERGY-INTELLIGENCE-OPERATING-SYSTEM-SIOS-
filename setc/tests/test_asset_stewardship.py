from datetime import datetime, timezone
from decimal import Decimal
import unittest

from setc.core import SETCIdentifier
from setc.organizations.asset_stewardship import (
    AssetRecord, AssetTransfer, AssetTransferState, AssetType,
    AssetValuationObservation, AssetVerification, ValuationStatus,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class AssetStewardshipTests(unittest.TestCase):
    def test_restricted_asset_requires_restriction_reference(self) -> None:
        with self.assertRaises(ValueError):
            AssetRecord(sid(1), sid(2), "asset:1", AssetType.REAL_ASSET, sid(2), restricted=True)

    def test_verified_valuation_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AssetValuationObservation(
                sid(1), sid(2), Decimal("100"), "USD",
                datetime.now(timezone.utc), ValuationStatus.VERIFIED,
            )

    def test_transfer_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            AssetTransfer(sid(1), sid(2), sid(3), sid(3), sid(4))

    def test_approved_transfer_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AssetTransfer(sid(1), sid(2), sid(3), sid(4), sid(5), AssetTransferState.APPROVED)

    def test_asset_verification_requires_independent_verifier(self) -> None:
        with self.assertRaises(ValueError):
            AssetVerification(sid(1), sid(2), sid(3), sid(3), "ownership", True, "evidence:1")

    def test_claimed_ownership_is_not_verified_ownership(self) -> None:
        asset = AssetRecord(sid(1), sid(2), "asset:1", AssetType.EQUIPMENT, sid(2))
        self.assertFalse(hasattr(asset, "verified_owner"))
        self.assertFalse(hasattr(asset, "liquid"))
        self.assertFalse(hasattr(asset, "unrestricted_value"))


if __name__ == "__main__":
    unittest.main()
