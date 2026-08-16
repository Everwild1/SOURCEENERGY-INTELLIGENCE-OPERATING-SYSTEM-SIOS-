from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.identity_authority import (
    AuthorityAssertion, DelegatedAuthority, IdentityStatus, InstitutionalIdentity,
    RepresentativeCapacity,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class IdentityAuthorityTests(unittest.TestCase):
    def test_verified_identity_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalIdentity(sid(1), sid(2), "Institution One", status=IdentityStatus.VERIFIED)

    def test_representative_capacity_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            RepresentativeCapacity(sid(1), sid(2), sid(2), "agent", "authority:1")

    def test_delegation_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            DelegatedAuthority(sid(1), sid(2), sid(2), "procurement", "authority:1", "evidence:1")

    def test_delegation_validity_window_must_be_ordered(self) -> None:
        now = datetime.now(timezone.utc)
        with self.assertRaises(ValueError):
            DelegatedAuthority(
                sid(1), sid(2), sid(3), "procurement", "authority:1", "evidence:1",
                valid_from=now, valid_until=now,
            )

    def test_verified_authority_assertion_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            AuthorityAssertion(sid(1), sid(2), "signing", "authorized signer", verified=True)

    def test_identity_does_not_imply_authority_or_ownership(self) -> None:
        identity = InstitutionalIdentity(sid(1), sid(2), "Institution One")
        self.assertFalse(hasattr(identity, "authority_scope"))
        self.assertFalse(hasattr(identity, "owner"))
        self.assertFalse(hasattr(identity, "transfer_authority"))


if __name__ == "__main__":
    unittest.main()
