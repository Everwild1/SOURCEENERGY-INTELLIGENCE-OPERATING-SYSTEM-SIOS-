from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.ventures import (
    EntrepreneurshipCenterProfile, FounderRelationship, LegalEntityFormation,
    VentureOrigin, VentureState,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class VentureFormationTests(unittest.TestCase):
    def test_center_requires_mandate(self) -> None:
        with self.assertRaises(ValueError):
            EntrepreneurshipCenterProfile(sid(1), " ")

    def test_origin_references_do_not_create_ip_ownership(self) -> None:
        origin = VentureOrigin(sid(1), sid(2), research_reference="research:7", ip_reference="ip:9")
        self.assertFalse(hasattr(origin, "owns_ip"))
        self.assertFalse(hasattr(origin, "ip_owner"))
        self.assertFalse(hasattr(origin, "assignment"))

    def test_founder_authority_is_explicit(self) -> None:
        founder = FounderRelationship(sid(1), sid(2), "person:alice")
        self.assertEqual(founder.authority.value, "NONE")

    def test_founder_relationship_dates_are_ordered(self) -> None:
        with self.assertRaises(ValueError):
            FounderRelationship(
                sid(1), sid(2), "person:alice",
                effective_from=datetime(2026, 2, 1, tzinfo=timezone.utc),
                effective_to=datetime(2026, 1, 1, tzinfo=timezone.utc),
            )

    def test_legal_formation_does_not_imply_ip_transfer(self) -> None:
        formation = LegalEntityFormation(sid(1), sid(2), sid(3), "US-NJ")
        self.assertFalse(hasattr(formation, "ip_assignment"))
        self.assertFalse(hasattr(formation, "research_ownership"))

    def test_legal_formation_requires_jurisdiction(self) -> None:
        with self.assertRaises(ValueError):
            LegalEntityFormation(sid(1), sid(2), sid(3), " ")

    def test_enterprise_activation_is_not_capital_certification(self) -> None:
        self.assertNotEqual(VentureState.ENTERPRISE_ACTIVATION.value, "CAPITAL_READY")


if __name__ == "__main__":
    unittest.main()
