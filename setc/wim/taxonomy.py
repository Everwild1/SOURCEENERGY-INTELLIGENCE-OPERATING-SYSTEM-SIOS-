"""Verified WITC economic-cluster registry metadata.

Source: https://wimexchange.com/the-west-indies-trading-company/
Verified against the live WITC page on 2026-08-20.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256

SOURCE_URL = "https://wimexchange.com/the-west-indies-trading-company/"
SOURCE_VERIFIED_ON = "2026-08-20"
TRADED_CLUSTER_RANGE = range(1, 52)
LOCAL_CLUSTER_RANGE = range(101, 117)


@dataclass(frozen=True, slots=True)
class TaxonomyRegistryInvariant:
    traded_numbers: tuple[int, ...]
    local_numbers: tuple[int, ...]

    def validate(self) -> None:
        if self.traded_numbers != tuple(TRADED_CLUSTER_RANGE):
            raise ValueError("WITC traded clusters must be contiguous 1..51")
        if self.local_numbers != tuple(LOCAL_CLUSTER_RANGE):
            raise ValueError("WITC local clusters must be contiguous 101..116")
        if set(self.traded_numbers) & set(self.local_numbers):
            raise ValueError("traded and local source numbering must not overlap")


def source_evidence_digest(evidence_text: str) -> str:
    """Return a stable digest for captured source evidence."""
    normalized = "\n".join(line.rstrip() for line in evidence_text.strip().splitlines())
    if not normalized:
        raise ValueError("source evidence is required")
    return sha256(normalized.encode("utf-8")).hexdigest()


def assert_cluster_counts(traded_count: int, local_count: int) -> None:
    if traded_count != 51:
        raise ValueError("expected 51 verified traded WITC clusters")
    if local_count != 16:
        raise ValueError("expected 16 verified local WITC clusters")
