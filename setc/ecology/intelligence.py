"""ECO-E05 deterministic Wealth Ecology intelligence projections."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from math import fsum
from typing import Mapping, Sequence


class MeasurementPosture(StrEnum):
    ESTIMATE = "estimate"
    OBSERVED = "observed"
    VERIFIED = "verified"


class IntelligenceMetric(StrEnum):
    VALUE_THROUGHPUT = "value_throughput"
    REGENERATIVE_RATIO = "regenerative_ratio"
    AUTHORITY_CONCENTRATION = "authority_concentration"
    DOMAIN_DIVERSITY = "domain_diversity"
    EVIDENCE_COVERAGE = "evidence_coverage"
    LIFECYCLE_VELOCITY = "lifecycle_velocity"


@dataclass(frozen=True, slots=True)
class IntelligenceInput:
    reference_id: str
    value: float
    source_authority: str
    posture: MeasurementPosture = MeasurementPosture.ESTIMATE
    confidence: float | None = None
    verification_authority: str | None = None

    def __post_init__(self) -> None:
        if not self.reference_id.strip() or not self.source_authority.strip():
            raise ValueError("reference_id and source_authority are required")
        if self.value < 0:
            raise ValueError("intelligence input value cannot be negative")
        if self.confidence is not None and not 0 <= self.confidence <= 1:
            raise ValueError("confidence must be between 0 and 1")
        if self.posture is MeasurementPosture.VERIFIED and not self.verification_authority:
            raise ValueError("verified input requires verification authority")


@dataclass(frozen=True, slots=True)
class IntelligenceResult:
    metric: IntelligenceMetric
    value: float
    posture: MeasurementPosture
    source_references: tuple[str, ...]
    explanation: Mapping[str, str] = field(default_factory=dict)

    @property
    def is_derived_projection(self) -> bool:
        return True

    @property
    def confers_settlement_finality(self) -> bool:
        return False

    @property
    def confers_ownership(self) -> bool:
        return False

    @property
    def confers_approval(self) -> bool:
        return False


def _derived_posture(inputs: Sequence[IntelligenceInput]) -> MeasurementPosture:
    # Aggregation never self-promotes evidence. Verified is retained only when every
    # contributing input is verified by an external/source authority.
    if inputs and all(i.posture is MeasurementPosture.VERIFIED for i in inputs):
        return MeasurementPosture.VERIFIED
    if inputs and all(i.posture in (MeasurementPosture.OBSERVED, MeasurementPosture.VERIFIED) for i in inputs):
        return MeasurementPosture.OBSERVED
    return MeasurementPosture.ESTIMATE


def value_throughput(inputs: Sequence[IntelligenceInput]) -> IntelligenceResult:
    total = fsum(i.value for i in inputs)
    return IntelligenceResult(
        IntelligenceMetric.VALUE_THROUGHPUT,
        total,
        _derived_posture(inputs),
        tuple(i.reference_id for i in inputs),
        {"formula": "sum(value)", "authority": "derived projection only"},
    )


def regenerative_ratio(reinvestment: float, realized_value: float, refs: Sequence[str] = ()) -> IntelligenceResult:
    if reinvestment < 0 or realized_value < 0:
        raise ValueError("values cannot be negative")
    ratio = 0.0 if realized_value == 0 else reinvestment / realized_value
    return IntelligenceResult(
        IntelligenceMetric.REGENERATIVE_RATIO,
        ratio,
        MeasurementPosture.ESTIMATE,
        tuple(refs),
        {"formula": "reinvestment / realized_value", "zero_denominator": "returns 0"},
    )


def authority_concentration(inputs: Sequence[IntelligenceInput]) -> IntelligenceResult:
    total = fsum(i.value for i in inputs)
    by_authority: dict[str, float] = {}
    for item in inputs:
        by_authority[item.source_authority] = by_authority.get(item.source_authority, 0.0) + item.value
    hhi = 0.0 if total == 0 else fsum((v / total) ** 2 for v in by_authority.values())
    return IntelligenceResult(
        IntelligenceMetric.AUTHORITY_CONCENTRATION,
        hhi,
        _derived_posture(inputs),
        tuple(i.reference_id for i in inputs),
        {"formula": "sum((authority_value / total_value)^2)", "range": "0..1"},
    )


def evidence_coverage(inputs: Sequence[IntelligenceInput]) -> IntelligenceResult:
    if not inputs:
        coverage = 0.0
    else:
        evidenced = sum(1 for i in inputs if i.confidence is not None)
        coverage = evidenced / len(inputs)
    return IntelligenceResult(
        IntelligenceMetric.EVIDENCE_COVERAGE,
        coverage,
        _derived_posture(inputs),
        tuple(i.reference_id for i in inputs),
        {"formula": "inputs_with_confidence / input_count", "range": "0..1"},
    )
