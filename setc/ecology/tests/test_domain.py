import unittest

from setc.ecology.domain import (
    AuthorityPosture,
    EcologyCorrelation,
    EcologyDomain,
    EcologyObjectReference,
    EvidenceReference,
    SetcOrganizationId,
)


class EcologyDomainTests(unittest.TestCase):
    def test_setc_organization_id_is_strict(self):
        valid = SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef")
        self.assertEqual(valid.value, "SETC-OID-0123456789abcdef0123456789abcdef")
        with self.assertRaises(ValueError):
            SetcOrganizationId("Example Institution")

    def test_cross_domain_reference_never_transfers_authority(self):
        ref = EcologyObjectReference(
            EcologyDomain.WIM,
            "transaction",
            "txn-001",
            "WIM Exchange",
        )
        self.assertFalse(ref.transfers_source_authority)
        self.assertFalse(ref.confers_settlement_finality)

    def test_source_coin_reference_never_confers_finality(self):
        ref = EcologyObjectReference(
            EcologyDomain.SOURCE_COIN,
            "product_journey",
            "journey-001",
            "Source Coin",
            AuthorityPosture.REFERENCE_ONLY,
        )
        self.assertFalse(ref.confers_settlement_finality)

    def test_non_setc_source_cannot_be_promoted_to_authoritative_projection(self):
        with self.assertRaises(ValueError):
            EcologyObjectReference(
                EcologyDomain.HEI,
                "ip_asset",
                "ip-001",
                "HEI",
                AuthorityPosture.AUTHORITATIVE_PROJECTION,
            )

    def test_reference_can_bind_canonical_org_and_evidence(self):
        ref = EcologyObjectReference(
            EcologyDomain.HEI,
            "commercialization_case",
            "case-001",
            "HEI",
            organization_id=SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef"),
            evidence=EvidenceReference("Source Block", "evidence-001"),
        )
        self.assertEqual(ref.organization_id.value, "SETC-OID-0123456789abcdef0123456789abcdef")
        self.assertFalse(ref.evidence.confers_verification)

    def test_blank_reference_fields_fail_closed(self):
        with self.assertRaises(ValueError):
            EcologyObjectReference(EcologyDomain.CRUDS, "work", "", "CRUDS")

    def test_correlation_requires_non_blank_values(self):
        correlation = EcologyCorrelation("corr-001", "cause-001", "idem-001")
        self.assertEqual(correlation.correlation_id, "corr-001")
        with self.assertRaises(ValueError):
            EcologyCorrelation(" ")
        with self.assertRaises(ValueError):
            EcologyCorrelation("corr-002", idempotency_key=" ")


if __name__ == "__main__":
    unittest.main()
