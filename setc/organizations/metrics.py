"""Organizational metrics and impact-ledger primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from setc.core import SETCIdentifier


class MetricValueType(StrEnum):
    NUMBER = "NUMBER"
    CURRENCY = "CURRENCY"
    PERCENTAGE = "PERCENTAGE"
    RATIO = "RATIO"
    COUNT = "COUNT"
    TEXT = "TEXT"


class ObservationStatus(StrEnum):
    REPORTED = "REPORTED"
    REVIEWED = "REVIEWED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"
    SUPERSEDED = "SUPERSEDED"


class ImpactClaimStatus(StrEnum):
    ASSERTED = "ASSERTED"
    UNDER_REVIEW = "UNDER_REVIEW"
    VALIDATED = "VALIDATED"
    REJECTED = "REJECTED"
    WITHDRAWN = "WITHDRAWN"


@dataclass(frozen=True, slots=True)
class MetricDefinition:
    metric_id: SETCIdentifier
    name: str
    value_type: MetricValueType
    unit: str
    description: str
    version: str

    def __post_init__(self) -> None:
        for value, label in (
            (self.name, "name"),
            (self.unit, "unit"),
            (self.description, "description"),
            (self.version, "version"),
        ):
            if not value.strip():
                raise ValueError(f"metric {label} cannot be blank")


@dataclass(frozen=True, slots=True)
class MeasurementPeriod:
    period_id: SETCIdentifier
    starts_at: datetime
    ends_at: datetime

    def __post_init__(self) -> None:
        if self.ends_at <= self.starts_at:
            raise ValueError("measurement period end must follow start")


@dataclass(frozen=True, slots=True)
class MetricObservation:
    observation_id: SETCIdentifier
    organization_id: SETCIdentifier
    metric_id: SETCIdentifier
    period_id: SETCIdentifier
    value: Decimal | str
    status: ObservationStatus = ObservationStatus.REPORTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    program_id: SETCIdentifier | None = None
    venture_id: SETCIdentifier | None = None
    observed_at: datetime | None = None

    def __post_init__(self) -> None:
        if isinstance(self.value, str) and not self.value.strip():
            raise ValueError("metric observation value cannot be blank")
        if self.status == ObservationStatus.VERIFIED and not self.evidence_references:
            raise ValueError("verified metric observations require evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("metric evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class MetricTarget:
    target_id: SETCIdentifier
    organization_id: SETCIdentifier
    metric_id: SETCIdentifier
    period_id: SETCIdentifier
    baseline_value: Decimal | None = None
    target_value: Decimal | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ImpactClaim:
    claim_id: SETCIdentifier
    organization_id: SETCIdentifier
    claim: str
    status: ImpactClaimStatus = ImpactClaimStatus.ASSERTED
    metric_observation_ids: tuple[SETCIdentifier, ...] = field(default_factory=tuple)
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.claim.strip():
            raise ValueError("impact claim cannot be blank")
        if self.status == ImpactClaimStatus.VALIDATED and not self.metric_observation_ids:
            raise ValueError("validated impact claims require supporting metric observations")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("impact evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ImpactValidation:
    validation_id: SETCIdentifier
    claim_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    validator_organization_id: SETCIdentifier
    validated: bool
    evidence_reference: str
    validated_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.validator_organization_id:
            raise ValueError("impact validation requires an independent validator")
        if not self.evidence_reference.strip():
            raise ValueError("impact validation requires evidence")
