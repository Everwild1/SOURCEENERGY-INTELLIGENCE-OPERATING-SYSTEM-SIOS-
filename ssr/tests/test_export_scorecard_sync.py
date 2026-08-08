import importlib.util
import unittest
from datetime import datetime, timezone
from pathlib import Path

TOOLS = Path(__file__).parents[1] / "tools"

VALIDATOR_SPEC = importlib.util.spec_from_file_location("validate_anchor_roster", TOOLS / "validate_anchor_roster.py")
validator = importlib.util.module_from_spec(VALIDATOR_SPEC)
assert VALIDATOR_SPEC and VALIDATOR_SPEC.loader
VALIDATOR_SPEC.loader.exec_module(validator)

import sys
sys.modules["validate_anchor_roster"] = validator

EXPORT_SPEC = importlib.util.spec_from_file_location("export_scorecard_sync", TOOLS / "export_scorecard_sync.py")
exporter = importlib.util.module_from_spec(EXPORT_SPEC)
assert EXPORT_SPEC and EXPORT_SPEC.loader
EXPORT_SPEC.loader.exec_module(exporter)


def row(anchor_id, w3w):
    return {
        "anchor_tile_id": anchor_id,
        "w3w_address": w3w,
        "latitude": 18.0,
        "longitude": -77.0,
        "activation_date": datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc).isoformat(),
        "status": "active",
        "surface_crs": "EPSG:4326",
        "vertical_datum": None,
        "source_system": "test-fixture",
        "source_record_id": None,
        "source_exported_at": None,
    }


class ScorecardSyncTests(unittest.TestCase):
    def test_builds_z0_address_and_sheet_rows(self):
        rows = [row("AT-0002", "///two.anchor.tile"), row("AT-0001", "///one.anchor.tile")]
        sync = exporter.build_sync_rows(rows)
        self.assertEqual("AT-0001", sync[0]["anchor_tile_id"])
        self.assertEqual(2, sync[0]["scorecard_row"])
        self.assertEqual("///one.anchor.tile@Z+0000", sync[0]["canonical_anchor_address"])
        self.assertEqual(3, sync[1]["scorecard_row"])

    def test_order_is_deterministic_by_authoritative_id(self):
        rows = [row("B", "///b.anchor.tile"), row("a", "///a.anchor.tile")]
        first = exporter.build_sync_rows(rows)
        second = exporter.build_sync_rows(list(reversed(rows)))
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
