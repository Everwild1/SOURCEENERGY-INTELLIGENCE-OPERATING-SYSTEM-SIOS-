import unittest

from setc.wim.verified_clusters import LOCAL_CLUSTERS, TRADED_CLUSTERS, validate_verified_snapshot


class VerifiedClusterSnapshotTests(unittest.TestCase):
    def test_snapshot_invariants(self):
        validate_verified_snapshot()

    def test_verified_counts(self):
        self.assertEqual(len(TRADED_CLUSTERS), 51)
        self.assertEqual(len(LOCAL_CLUSTERS), 16)

    def test_authoritative_source_numbering(self):
        self.assertEqual(TRADED_CLUSTERS[0][0], 1)
        self.assertEqual(TRADED_CLUSTERS[-1][0], 51)
        self.assertEqual(LOCAL_CLUSTERS[0][0], 101)
        self.assertEqual(LOCAL_CLUSTERS[-1][0], 116)

    def test_no_top_level_name_duplicates(self):
        names = [name for _, name in (*TRADED_CLUSTERS, *LOCAL_CLUSTERS)]
        self.assertEqual(len(names), len(set(names)))


if __name__ == "__main__":
    unittest.main()
