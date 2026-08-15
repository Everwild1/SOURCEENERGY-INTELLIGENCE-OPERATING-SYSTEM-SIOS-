"""Ecosystem reporting and institutional-intelligence primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ReportingScope(StrEnum):
    ORGANIZATION = "ORGANIZATION"
    PROGRAM = "PROGRAM"
    COHORT = "COHORT"
    FOUNDATION = "FOUNDATION"
    VENTURE = "VENTURE"
    ECOSYSTEM = "ECOSYSTEM"


class SnapshotStatus(StrEnum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    SUPERSEDED = "SUPERSEDED"
    WITHDRAWN = "WITHDRAWN"


@dataclass(frozen=True, slots=True)
class ReportingDefinition:
    definition_id: SETCIdentifier
    name: str
    scope: ReportingScope
    version: str
    metric_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip():
            raise ValueError("reporting definition requires name and version")
        if any(not ref.strip() for ref in self.metric_references):
            raise ValueError("metric references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ReportingSnapshot:
    snapshot_id: SETCIdentifier
    definition_id: SETCIdentifier
    scope_reference: str
    generated_at: datetime
    status: SnapshotStatus = SnapshotStatus.DRAFT
    source_evidence_references: tuple[str, ...] = field(default_factory=tuple)
    source_record_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.scope_reference.strip():
            raise ValueError("scope_reference cannot be blank")
        if any(not ref.strip() for ref in self.source_evidence_references):
            raise ValueError("source evidence references cannot contain blanks")
        if any(not ref.strip() for ref in self.source_record_references):
            raise ValueError("source record references cannot contain blanks")
        if self.status == SnapshotStatus.PUBLISHED and not self.source_record_references:
            raise ValueError("published reporting snapshots require source records")


@dataclass(frozen=True, slots=True)
class PortfolioAggregate:
    aggregate_id: SETCIdentifier
    snapshot_id: SETCIdentifier
    metric_reference: str
    value: str
    aggregation_method: str
    source_count: int

    def __post_init__(self) -> None:
        if not self.metric_reference.strip() or not self.value.strip() or not self.aggregation_method.strip():
            raise ValueError("aggregate requires metric, value, and aggregation method")
        if self.source_count < 0:
            raise ValueError("source_count cannot be negative")


@dataclass(frozen=True, slots=True)
class InstitutionalInsight:
    insight_id: SETCIdentifier
    snapshot_id: SETCIdentifier
    title: str
    narrative: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    verified: bool = False

    def __post_init__(self) -> None:
        if not self.title.strip() or not self.narrative.strip():
            raise ValueError("institutional insight requires title and narrative")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("insight evidence references cannot contain blanks")
        if self.verified and not self.evidence_references:
            raise ValueError("verified insights require evidence")


@dataclass(frozen=True, slots=True)
class PipelinePosition:
    position_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    stage: str
    source_record_reference: str
    recorded_at: datetime

    def __post_init__(self) -> None:
        if not self.stage.strip() or not self.source_record_reference.strip():
            raise ValueError("pipeline position requires stage and source record")


@dataclass(frozen=True, slots=True)
class ReportingDistribution:
    distribution_id: SETCIdentifier
    snapshot_id: SETCIdentifier
    dimension: str
    bucket: str
    count: int

    def __post_init__(self) -> None:
        if not self.dimension.strip() or not self.bucket.strip():
            raise ValueError("distribution requires dimension and bucket")
        if self.count < 0:
            raise ValueError("distribution count cannot be negative")
