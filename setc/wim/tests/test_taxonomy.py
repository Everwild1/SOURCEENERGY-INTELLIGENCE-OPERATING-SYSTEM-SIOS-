import unittest

from setc.wim.taxonomy import (
    TaxonomyRegistryInvariant,
    assert_cluster_counts,
    source_evidence_digest,
)


class WimTaxonomyTests(unittest.TestCase):
    def test_verified_source_ranges(self):
        TaxonomyRegistryInvariant(tuple(range(1, 52)), tuple(range(101, 117))).validate()

    def test_missing_traded_number_fails(self):
        with self.assertRaises(ValueError):
            TaxonomyRegistryInvariant(tuple(range(1, 51)), tuple(range(101, 117))).validate()

    def test_local_source_numbers_are_101_through_116(self):
        with self.assertRaises(ValueError):
            TaxonomyRegistryInvariant(tuple(range(1, 52)), tuple(range(1, 17))).validate()

    def test_cluster_counts(self):
        assert_cluster_counts(51, 16)
        with self.assertRaises(ValueError):
            assert_cluster_counts(50, 16)

    def test_source_digest_is_deterministic(self):
        self.assertEqual(source_evidence_digest("a\nb"), source_evidence_digest("a\nb"))
        self.assertEqual(len(source_evidence_digest("evidence")), 64)


if __name__ == "__main__":
    unittest.main()
