import unittest

from setc.wim.domain import (
    EconomicCluster,
    EconomicClusterScope,
    OrganizationBinding,
    OrganizationEconomicStatus,
    SetcOrganizationId,
    SourceCoinRequestReference,
    VerificationStatus,
)
from setc.wim.integration_contracts import SourceCoinEconomicRequest


class WimDomainTests(unittest.TestCase):
    def test_setc_organization_id_is_strict(self):
        valid = SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef")
        self.assertTrue(valid.value.startswith("SETC-OID-"))
        with self.assertRaises(ValueError):
            SetcOrganizationId("SETC-OID-NOT-CANONICAL")

    def test_pending_cluster_cannot_be_canonical(self):
        cluster = EconomicCluster(
            "WIM-T01", 1, "Transportation and Logistics",
            EconomicClusterScope.TRADED, "https://wimexchange.com/source", False,
        )
        with self.assertRaises(ValueError):
            cluster.require_canonical_use()

    def test_verified_active_org_can_trade(self):
        org = OrganizationBinding(
            SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef"),
            "Example Institution",
            VerificationStatus.VERIFIED,
            OrganizationEconomicStatus.ACTIVE,
        )
        org.require_commercial_activity()

    def test_unverified_org_fails_closed(self):
        org = OrganizationBinding(
            SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef"),
            "Example Institution",
        )
        with self.assertRaises(ValueError):
            org.require_commercial_activity()

    def test_source_coin_reference_never_confers_finality(self):
        ref = SourceCoinRequestReference("wim-request-001")
        self.assertFalse(ref.confers_settlement_finality)

    def test_source_coin_request_is_request_only(self):
        request = SourceCoinEconomicRequest("req-1", "txn-1", "settlement", {"amount": "10"})
        envelope = request.to_envelope()
        self.assertEqual(envelope.payload["authority_boundary"], "request_only_no_ledger_mutation")


if __name__ == "__main__":
    unittest.main()
