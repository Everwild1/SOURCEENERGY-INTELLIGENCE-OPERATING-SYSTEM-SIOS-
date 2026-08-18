"""Machine-readable SETC release assurance metadata.

This module records software release evidence only. It does not assert external
certification, accreditation, legal authority, financial entitlement, or SLA.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


SETC_RELEASE_SCHEMA_VERSION = "1.0"
SETC_PHASE = "II"
COMPLETED_WORKSTREAMS = ("II-A", "II-B", "II-C")
REQUIRED_RELEASE_GATES = (
    "setc-core-ci",
    "integration-regression",
    "public-api-stability",
    "observability-contract",
    "integration-contract",
    "dependency-security-review",
)


@dataclass(frozen=True, slots=True)
class ReleaseAssuranceManifest:
    schema_version: str = SETC_RELEASE_SCHEMA_VERSION
    phase: str = SETC_PHASE
    completed_workstreams: tuple[str, ...] = COMPLETED_WORKSTREAMS
    required_gates: tuple[str, ...] = REQUIRED_RELEASE_GATES

    def __post_init__(self) -> None:
        if self.schema_version != SETC_RELEASE_SCHEMA_VERSION:
            raise ValueError("unsupported release assurance schema version")
        if self.phase != SETC_PHASE:
            raise ValueError("release assurance phase mismatch")
        if tuple(self.completed_workstreams) != COMPLETED_WORKSTREAMS:
            raise ValueError("release assurance lineage mismatch")
        if not self.required_gates or len(set(self.required_gates)) != len(self.required_gates):
            raise ValueError("release assurance gates must be unique and non-empty")

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["completed_workstreams"] = list(self.completed_workstreams)
        data["required_gates"] = list(self.required_gates)
        return data


def verify_release_gate_evidence(manifest: ReleaseAssuranceManifest, evidence: set[str]) -> None:
    missing = set(manifest.required_gates) - set(evidence)
    if missing:
        raise ValueError(f"missing release gate evidence: {', '.join(sorted(missing))}")
