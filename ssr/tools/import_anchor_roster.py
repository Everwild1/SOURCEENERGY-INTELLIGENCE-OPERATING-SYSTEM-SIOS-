#!/usr/bin/env python3
"""Normalize a validated SSR AnchorTile roster into a canonical CSV import artifact."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from validate_anchor_roster import RosterValidationError, load_rows, validate_rows

OUTPUT_FIELDS = [
    "anchor_tile_id",
    "w3w_address",
    "latitude",
    "longitude",
    "activation_date",
    "status",
    "surface_crs",
    "vertical_datum",
    "source_system",
    "source_record_id",
    "source_exported_at",
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate and normalize the authoritative SSR 729-row AnchorTile roster"
    )
    parser.add_argument("input", type=Path, help="Authoritative source export (.csv or .json)")
    parser.add_argument("output", type=Path, help="Destination canonical CSV")
    args = parser.parse_args()

    if args.output.exists():
        print(f"refusing to overwrite existing output: {args.output}", file=sys.stderr)
        return 2

    try:
        normalized = validate_rows(load_rows(args.input))
    except (OSError, RosterValidationError, ValueError) as exc:
        print(f"SSR roster import BLOCKED:\n{exc}", file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(normalized)

    print(f"SSR roster import artifact created: {args.output} ({len(normalized)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
