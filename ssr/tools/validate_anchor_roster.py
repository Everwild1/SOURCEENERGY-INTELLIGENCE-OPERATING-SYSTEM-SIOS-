#!/usr/bin/env python3
"""Validate an authoritative SSR AnchorTile roster before production ingestion.

Default production policy is intentionally strict: exactly 729 records are required.
This tool does not generate AnchorTile IDs, What3Words addresses, coordinates, or
activation timestamps.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

EXPECTED_PRODUCTION_COUNT = 729
W3W_RE = re.compile(r"^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$")
REQUIRED_FIELDS = (
    "anchor_tile_id",
    "w3w_address",
    "latitude",
    "longitude",
    "activation_date",
    "source_system",
)


class RosterValidationError(ValueError):
    pass


def _parse_datetime(value: str, field: str, row_number: int) -> None:
    normalized = value.strip().replace("Z", "+00:00")
    try:
        datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise RosterValidationError(
            f"row {row_number}: {field} must be ISO-8601 date/time, got {value!r}"
        ) from exc


def _parse_coordinate(value: Any, field: str, row_number: int, low: float, high: float) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise RosterValidationError(
            f"row {row_number}: {field} must be numeric, got {value!r}"
        ) from exc
    if not low <= number <= high:
        raise RosterValidationError(
            f"row {row_number}: {field}={number} outside [{low}, {high}]"
        )
    return number


def validate_rows(rows: Iterable[dict[str, Any]], expected_count: int = EXPECTED_PRODUCTION_COUNT) -> list[dict[str, Any]]:
    materialized = [dict(row) for row in rows]
    errors: list[str] = []

    if len(materialized) != expected_count:
        errors.append(f"expected exactly {expected_count} records; found {len(materialized)}")

    seen_ids: set[str] = set()
    seen_w3w: set[str] = set()
    normalized_rows: list[dict[str, Any]] = []

    for index, row in enumerate(materialized, start=1):
        missing = [field for field in REQUIRED_FIELDS if str(row.get(field, "")).strip() == ""]
        if missing:
            errors.append(f"row {index}: missing required field(s): {', '.join(missing)}")
            continue

        anchor_tile_id = str(row["anchor_tile_id"]).strip()
        w3w_address = str(row["w3w_address"]).strip()
        source_system = str(row["source_system"]).strip()
        activation_date = str(row["activation_date"]).strip()

        if anchor_tile_id in seen_ids:
            errors.append(f"row {index}: duplicate anchor_tile_id {anchor_tile_id!r}")
        else:
            seen_ids.add(anchor_tile_id)

        if w3w_address in seen_w3w:
            errors.append(f"row {index}: duplicate w3w_address {w3w_address!r}")
        else:
            seen_w3w.add(w3w_address)

        if not W3W_RE.fullmatch(w3w_address):
            errors.append(f"row {index}: invalid W3W surface address {w3w_address!r}")

        try:
            latitude = _parse_coordinate(row["latitude"], "latitude", index, -90, 90)
            longitude = _parse_coordinate(row["longitude"], "longitude", index, -180, 180)
            _parse_datetime(activation_date, "activation_date", index)
        except RosterValidationError as exc:
            errors.append(str(exc))
            continue

        source_record_id = str(row.get("source_record_id", "")).strip()
        source_exported_at = str(row.get("source_exported_at", "")).strip()
        if source_exported_at:
            try:
                _parse_datetime(source_exported_at, "source_exported_at", index)
            except RosterValidationError as exc:
                errors.append(str(exc))

        normalized_rows.append(
            {
                "anchor_tile_id": anchor_tile_id,
                "w3w_address": w3w_address,
                "latitude": latitude,
                "longitude": longitude,
                "activation_date": activation_date,
                "status": str(row.get("status", "active")).strip() or "active",
                "surface_crs": str(row.get("surface_crs", "EPSG:4326")).strip() or "EPSG:4326",
                "vertical_datum": str(row.get("vertical_datum", "")).strip() or None,
                "source_system": source_system,
                "source_record_id": source_record_id or None,
                "source_exported_at": source_exported_at or None,
            }
        )

    if errors:
        raise RosterValidationError("\n".join(errors))
    return normalized_rows


def load_rows(path: Path) -> list[dict[str, Any]]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            return list(csv.DictReader(handle))
    if suffix == ".json":
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if not isinstance(payload, list) or not all(isinstance(item, dict) for item in payload):
            raise RosterValidationError("JSON input must be an array of objects")
        return payload
    raise RosterValidationError("input must be .csv or .json")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the canonical 729-row SSR AnchorTile roster")
    parser.add_argument("input", type=Path, help="Authoritative roster export (.csv or .json)")
    parser.add_argument("--normalized-json", type=Path, help="Write normalized JSON only after validation succeeds")
    args = parser.parse_args()

    try:
        rows = load_rows(args.input)
        normalized = validate_rows(rows)
    except (OSError, json.JSONDecodeError, RosterValidationError) as exc:
        print(f"SSR roster validation FAILED:\n{exc}", file=sys.stderr)
        return 1

    if args.normalized_json:
        args.normalized_json.write_text(json.dumps(normalized, indent=2) + "\n", encoding="utf-8")

    print(f"SSR roster validation PASSED: {len(normalized)} authoritative AnchorTile records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
