import unittest

from setc.core import SETCIdentifier
from setc.organizations.commercialization import (
    CommercializationOpportunity, IPAssetReference, IPRightType,
    RightsInstrument, RightsInstrumentType, TechnologyTransferAuthority,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class CommercializationTests(unittest.TestCase):
    def test_ip_reference_claim_is_not_assignment(self) -> None:
        asset = IPAssetReference("ip:1", IPRightType.PATENT, claimed_owner_organization_id=sid(1))
        self.assertFalse(hasattr(asset, "assigned_to"))
        self.assertFalse(hasattr(asset, "transfer_effective"))

    def test_authority_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            TechnologyTransferAuthority(sid(1), sid(2), "licensing", " ")

    def test_rights_instrument_requires_distinct_parties(self) -> None:
        with self.assertRaises(ValueError):
            RightsInstrument(sid(1), "ip:1", RightsInstrumentType.LICENSE, sid(2), sid(2), sid(3), "instrument:7")

    def test_assignment_requires_explicit_instrument_type(self) -> None:
        instrument = RightsInstrument(
            sid(1), "ip:1", RightsInstrumentType.ASSIGNMENT,
            sid(2), sid(3), sid(4), "assignment:executed",
        )
        self.assertEqual(instrument.instrument_type, RightsInstrumentType.ASSIGNMENT)
        self.assertTrue(instrument.evidence_reference)

    def test_commercialization_link_is_not_ip_transfer(self) -> None:
        opportunity = CommercializationOpportunity(sid(1), "research:1", sid(2), venture_id=sid(3), ip_reference="ip:1")
        self.assertFalse(hasattr(opportunity, "ownership_transferred"))
        self.assertFalse(hasattr(opportunity, "assignee"))


if __name__ == "__main__":
    unittest.main()
