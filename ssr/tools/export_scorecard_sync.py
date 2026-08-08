#!/usr/bin/env python3
"""Export validated SSR AnchorTiles into a deterministic scorecard synchronization file."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from validate_anchor_roster import RosterValidationError, load_rows, validate_rows

FIELDS = [
    "scorecard_row",
    "anchor_tile_id",
    "canonical_anchor_address",
    "w3w_address",
    "latitude",
    "longitude",
    "activation_date",
    "status",
    "source_system",
    "source_record_id",
]


def canonical_z0(w3w_address: str) -> str:
    return f"{w3w_address}@Z+0000"


def sort_key(row: dict) -> tuple[str, str]:
    # The authoritative ID is the primary stable ordering key. W3W is a deterministic tie-breaker,
    # though duplicate IDs are already rejected by validation.
    return (row["anchor_tile_id"].casefold(), row["w3w_address"].casefold())


def build_sync_rows(rows: list[dict]) -> list[dict]:
    ordered = sorted(rows, key=sort_key)
    return [
        {
            "scorecard_row": index + 2,  # row 1 is the Google Sheets header
            "anchor_tile_id": row["anchor_tile_id"],
            "canonical_anchor_address": canonical_z0(row["w3w_address"]),
            "w3w_address": row["w3w_address"],
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "activation_date": row["activation_date"],
            "status": row["status"],
            "source_system": row["source_system"],
            "source_record_id": row["source_record_id"] or "",
        }
        for index, row in enumerate(ordered)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Create deterministic SSR-to-scorecard sync CSV")
    parser.add_argument("input", type=Path, help="Validated authoritative roster (.csv or .json)")
    parser.add_argument("output", type=Path, help="Destination sync CSV")
    args = parser.parse_args()

    if args.output.exists():
        print(f"refusing to overwrite existing output: {args.output}", file=sys.stderr)
        return 2

    try:
        rows = validate_rows(load_rows(args.input))
    except (OSError, RosterValidationError, ValueError) as exc:
        print(f"SSR scorecard export BLOCKED:\n{exc}", file=sys.stderr)
        return 1

    sync_rows = build_sync_rows(rows)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(sync_rows)

    print(f"SSR scorecard sync export created: {args.output} ({len(sync_rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
