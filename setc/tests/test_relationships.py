from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.relationships import OrganizationRelationship, RelationshipState, RelationshipType


def oid(hex_value: str) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{hex_value}")


class OrganizationRelationshipTests(unittest.TestCase):
    def setUp(self) -> None:
        self.a = oid("00000000000000000000000000000001")
        self.b = oid("00000000000000000000000000000002")
        self.rid = oid("00000000000000000000000000000003")

    def test_self_relationship_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            OrganizationRelationship(self.rid, self.a, self.a, RelationshipType.FUNDS)

    def test_invalid_effective_window_is_rejected(self) -> None:
        later = datetime(2026, 2, 1, tzinfo=timezone.utc)
        earlier = datetime(2026, 1, 1, tzinfo=timezone.utc)
        with self.assertRaises(ValueError):
            OrganizationRelationship(
                self.rid, self.a, self.b, RelationshipType.FUNDS,
                effective_from=later, effective_to=earlier,
            )

    def test_asserted_state_is_not_verified(self) -> None:
        relationship = OrganizationRelationship(self.rid, self.a, self.b, RelationshipType.FUNDS)
        self.assertEqual(relationship.state, RelationshipState.ASSERTED)
        self.assertNotEqual(relationship.state, RelationshipState.VERIFIED)

    def test_symmetric_relationship_inverts_to_same_type(self) -> None:
        relationship = OrganizationRelationship(self.rid, self.a, self.b, RelationshipType.PARTNERS_WITH)
        inverse = relationship.inverse()
        self.assertEqual(inverse.relationship_type, RelationshipType.PARTNERS_WITH)
        self.assertEqual(inverse.source_organization_id, self.b)
        self.assertEqual(inverse.target_organization_id, self.a)

    def test_governed_inverse_mapping(self) -> None:
        relationship = OrganizationRelationship(self.rid, self.a, self.b, RelationshipType.PROCURES_FROM)
        self.assertEqual(relationship.inverse().relationship_type, RelationshipType.SUPPLIES_TO)

    def test_directional_relationship_without_inverse_fails_closed(self) -> None:
        relationship = OrganizationRelationship(self.rid, self.a, self.b, RelationshipType.FUNDS)
        with self.assertRaises(ValueError):
            relationship.inverse()

    def test_blank_evidence_reference_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            OrganizationRelationship(
                self.rid, self.a, self.b, RelationshipType.VERIFIED_BY,
                evidence_reference="   ",
            )


if __name__ == "__main__":
    unittest.main()
