import unittest
from uuid import UUID

from setc.wim.domain import (
    OrganizationBinding,
    OrganizationEconomicStatus,
    SetcOrganizationId,
    VerificationStatus,
)
from setc.wim.organization_market_graph import (
    CorridorRole,
    Market,
    MarketRole,
    OrganizationCorridorMembership,
    OrganizationMarketMembership,
    ParticipationStatus,
    TradeCorridor,
)

ORG_ID = SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef")
M1 = UUID("00000000-0000-0000-0000-000000000001")
M2 = UUID("00000000-0000-0000-0000-000000000002")
C1 = UUID("00000000-0000-0000-0000-000000000003")


def active_org():
    return OrganizationBinding(ORG_ID, "Example Institution", VerificationStatus.VERIFIED, OrganizationEconomicStatus.ACTIVE)


class OrganizationMarketGraphTests(unittest.TestCase):
    def test_one_setc_identity_can_have_multiple_market_roles(self):
        market = Market(M1, "Caribbean Market")
        buyer = OrganizationMarketMembership(active_org(), market, MarketRole.BUYER)
        exporter = OrganizationMarketMembership(active_org(), market, MarketRole.EXPORTER)
        self.assertEqual(buyer.organization.setc_organization_id, exporter.organization.setc_organization_id)
        self.assertNotEqual(buyer.role, exporter.role)

    def test_restricted_organization_fails_closed(self):
        org = OrganizationBinding(ORG_ID, "Example Institution", VerificationStatus.VERIFIED, OrganizationEconomicStatus.RESTRICTED)
        edge = OrganizationMarketMembership(org, Market(M1, "Market"), MarketRole.SELLER, ParticipationStatus.ACTIVE, "evidence:1")
        with self.assertRaises(ValueError):
            edge.authorize_active_participation()

    def test_restricted_market_fails_closed(self):
        edge = OrganizationMarketMembership(active_org(), Market(M1, "Market", status="restricted"), MarketRole.BUYER, ParticipationStatus.ACTIVE, "evidence:2")
        with self.assertRaises(ValueError):
            edge.authorize_active_participation()

    def test_active_membership_requires_provenance(self):
        edge = OrganizationMarketMembership(active_org(), Market(M1, "Market"), MarketRole.BUYER, ParticipationStatus.ACTIVE)
        with self.assertRaises(ValueError):
            edge.authorize_active_participation()

    def test_active_market_membership_authorizes(self):
        edge = OrganizationMarketMembership(active_org(), Market(M1, "Market"), MarketRole.SUPPLIER, ParticipationStatus.ACTIVE, "source-block:organization-binding")
        edge.authorize_active_participation()

    def test_corridor_cannot_loop_to_same_market(self):
        with self.assertRaises(ValueError):
            TradeCorridor(C1, "Invalid", M1, M1, "active")

    def test_active_corridor_membership_authorizes(self):
        corridor = TradeCorridor(C1, "Caribbean-US", M1, M2, "active")
        edge = OrganizationCorridorMembership(active_org(), corridor, CorridorRole.EXPORTER, ParticipationStatus.ACTIVE, "corridor:evidence:1")
        edge.authorize_active_participation()


if __name__ == "__main__":
    unittest.main()
