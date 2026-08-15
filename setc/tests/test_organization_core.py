import unittest

from setc.core import SETCIdentifier, new_setc_oid
from setc.organizations import Organization, OrganizationCapability, OrganizationType, VerificationState


class IdentifierTests(unittest.TestCase):
    def test_new_oid_round_trips(self):
        oid = new_setc_oid()
        self.assertTrue(str(oid).startswith("SETC-OID-"))
        self.assertEqual(SETCIdentifier(str(oid)), oid)

    def test_invalid_oid_rejected(self):
        with self.assertRaises(ValueError):
            SETCIdentifier("SETC-OID-not-a-uuid")


class OrganizationTests(unittest.TestCase):
    def test_one_identity_supports_multiple_capabilities(self):
        organization = Organization(
            oid=new_setc_oid(),
            legal_name="SourceEnergy Research Foundation",
            organization_type=OrganizationType.FOUNDATION,
            verification_state=VerificationState.VERIFIED,
            capabilities={
                OrganizationCapability.GRANTS,
                OrganizationCapability.RESEARCHES,
                OrganizationCapability.INCUBATES,
            },
        )
        self.assertEqual(len(organization.capabilities), 3)
        self.assertEqual(organization.verification_state, VerificationState.VERIFIED)

    def test_blank_legal_name_rejected(self):
        with self.assertRaises(ValueError):
            Organization(
                oid=new_setc_oid(),
                legal_name="   ",
                organization_type=OrganizationType.OTHER,
            )

    def test_aliases_are_normalized_without_mutating_identity(self):
        oid = new_setc_oid()
        organization = Organization(
            oid=oid,
            legal_name="Example University",
            organization_type=OrganizationType.UNIVERSITY,
            aliases={" EU ", ""},
        )
        self.assertEqual(organization.oid, oid)
        self.assertEqual(organization.aliases, {"EU"})


if __name__ == "__main__":
    unittest.main()
