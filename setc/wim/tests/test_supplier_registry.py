import unittest
from decimal import Decimal

from setc.wim.domain import OrganizationBinding, OrganizationEconomicStatus, SetcOrganizationId, VerificationStatus
from setc.wim.supplier_registry import AvailabilityStatus, OfferingType, PriceReference, SupplierOffering

OID = SetcOrganizationId("SETC-OID-0123456789abcdef0123456789abcdef")


def supplier(status=OrganizationEconomicStatus.ACTIVE, verification=VerificationStatus.VERIFIED):
    return OrganizationBinding(OID, "Verified Supplier", verification, status)


class SupplierRegistryTests(unittest.TestCase):
    def test_verified_active_supplier_can_publish_verified_supply(self):
        offering = SupplierOffering(supplier(), "Regional Logistics", OfferingType.SERVICE, "WIM-T45-S01", AvailabilityStatus.AVAILABLE, VerificationStatus.VERIFIED, "evidence:qualification:1")
        offering.require_publishable()

    def test_unverified_offering_fails_closed(self):
        offering = SupplierOffering(supplier(), "Regional Logistics", OfferingType.SERVICE, "WIM-T45-S01", AvailabilityStatus.AVAILABLE)
        with self.assertRaises(ValueError):
            offering.require_publishable()

    def test_suspended_supplier_cannot_publish(self):
        offering = SupplierOffering(supplier(OrganizationEconomicStatus.SUSPENDED), "Regional Logistics", OfferingType.SERVICE, "WIM-T45-S01", AvailabilityStatus.AVAILABLE, VerificationStatus.VERIFIED, "evidence:1")
        with self.assertRaises(ValueError):
            offering.require_publishable()

    def test_provenance_is_required(self):
        offering = SupplierOffering(supplier(), "Regional Logistics", OfferingType.SERVICE, "WIM-T45-S01", AvailabilityStatus.AVAILABLE, VerificationStatus.VERIFIED)
        with self.assertRaises(ValueError):
            offering.require_publishable()

    def test_price_is_reference_not_settlement(self):
        price = PriceReference(Decimal("1250.00"), "usd")
        self.assertEqual(price.currency, "USD")
        self.assertFalse(price.confers_payment_or_settlement)

    def test_catalog_never_creates_settlement_finality(self):
        offering = SupplierOffering(supplier(), "Product", OfferingType.PRODUCT, "WIM-T09-S03")
        self.assertFalse(offering.creates_settlement_finality)


if __name__ == "__main__":
    unittest.main()
