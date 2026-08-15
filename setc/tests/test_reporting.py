from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.reporting import (
    InstitutionalInsight, PortfolioAggregate, ReportingDefinition, ReportingScope,
    ReportingSnapshot, SnapshotStatus,
)


def sid(n: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{n:032x}")


class ReportingTests(unittest.TestCase):
    def test_published_snapshot_requires_source_records(self) -> None:
        with self.assertRaises(ValueError):
            ReportingSnapshot(sid(1), sid(2), "ecosystem:all", datetime.now(timezone.utc), SnapshotStatus.PUBLISHED)

    def test_draft_snapshot_can_be_empty(self) -> None:
        snapshot = ReportingSnapshot(sid(1), sid(2), "program:1", datetime.now(timezone.utc))
        self.assertEqual(snapshot.status, SnapshotStatus.DRAFT)

    def test_verified_insight_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            InstitutionalInsight(sid(1), sid(2), "Trend", "Narrative", verified=True)

    def test_report_definition_rejects_blank_metric_reference(self) -> None:
        with self.assertRaises(ValueError):
            ReportingDefinition(sid(1), "Portfolio", ReportingScope.ECOSYSTEM, "1.0", (" ",))

    def test_aggregate_source_count_cannot_be_negative(self) -> None:
        with self.assertRaises(ValueError):
            PortfolioAggregate(sid(1), sid(2), "metric:jobs", "10", "SUM", -1)

    def test_analytics_are_not_certification(self) -> None:
        insight = InstitutionalInsight(sid(1), sid(2), "Readiness mix", "Observed distribution")
        self.assertFalse(hasattr(insight, "certified"))
        self.assertFalse(hasattr(insight, "endorsed"))


if __name__ == "__main__":
    unittest.main()
