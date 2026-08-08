import importlib.util
import unittest
from datetime import datetime, timezone
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "tools" / "validate_anchor_roster.py"
SPEC = importlib.util.spec_from_file_location("validate_anchor_roster", MODULE_PATH)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(validator)


def valid_rows(count=729):
    stamp = datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc).isoformat()
    return [
        {
            "anchor_tile_id": f"AT-{i:04d}",
            "w3w_address": f"///anchor{i}.tile{i}.ssr{i}",
            "latitude": 18.0 + (i / 100000),
            "longitude": -77.0 - (i / 100000),
            "activation_date": stamp,
            "source_system": "test-fixture",
        }
        for i in range(1, count + 1)
    ]


class AnchorRosterValidationTests(unittest.TestCase):
    def test_accepts_complete_unique_729_row_roster(self):
        rows = validator.validate_rows(valid_rows())
        self.assertEqual(729, len(rows))

    def test_rejects_wrong_record_count(self):
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(valid_rows(728))

    def test_rejects_duplicate_anchor_id(self):
        rows = valid_rows()
        rows[1]["anchor_tile_id"] = rows[0]["anchor_tile_id"]
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(rows)

    def test_rejects_duplicate_w3w(self):
        rows = valid_rows()
        rows[1]["w3w_address"] = rows[0]["w3w_address"]
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(rows)

    def test_rejects_z_indexed_w3w_as_surface_anchor(self):
        rows = valid_rows()
        rows[0]["w3w_address"] = "///example.anchor.tile@Z+0000"
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(rows)

    def test_rejects_invalid_coordinate(self):
        rows = valid_rows()
        rows[0]["latitude"] = 91
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(rows)

    def test_rejects_unparseable_activation_date(self):
        rows = valid_rows()
        rows[0]["activation_date"] = "April fifth"
        with self.assertRaises(validator.RosterValidationError):
            validator.validate_rows(rows)


if __name__ == "__main__":
    unittest.main()
