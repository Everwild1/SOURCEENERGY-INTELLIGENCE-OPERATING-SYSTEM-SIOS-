"""ECO-PH-04 operational resilience and degraded-mode contracts."""
from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Iterable

from .domain import EcologyDomain


class DependencyState(StrEnum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"
    RELEASE_BLOCKED = "release_blocked"


class RecoveryDecision(StrEnum):
    NORMAL = "normal"
    READ_ONLY = "read_only"
    FAIL_CLOSED = "fail_closed"


@dataclass(frozen=True, slots=True)
class DependencyHealth:
    domain: EcologyDomain
    state: DependencyState
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.evidence_reference.strip():
            raise ValueError("dependency health requires evidence")


@dataclass(frozen=True, slots=True)
class RecoveryAssessment:
    decision: RecoveryDecision
    reasons: tuple[str, ...]

    @property
    def confers_source_authority(self) -> bool:
        return False

    @property
    def authorizes_financial_execution(self) -> bool:
        return False

    @property
    def bypasses_release_gate(self) -> bool:
        return False


def assess_dependencies(dependencies: Iterable[DependencyHealth]) -> RecoveryAssessment:
    deps = tuple(dependencies)
    if not deps:
        return RecoveryAssessment(RecoveryDecision.FAIL_CLOSED, ("dependency_health_missing",))

    blocked = [d for d in deps if d.state in {DependencyState.UNAVAILABLE, DependencyState.RELEASE_BLOCKED}]
    if blocked:
        reasons = tuple(f"{d.domain.value}:{d.state.value}" for d in blocked)
        return RecoveryAssessment(RecoveryDecision.FAIL_CLOSED, reasons)

    degraded = [d for d in deps if d.state is DependencyState.DEGRADED]
    if degraded:
        return RecoveryAssessment(
            RecoveryDecision.READ_ONLY,
            tuple(f"{d.domain.value}:degraded" for d in degraded),
        )

    return RecoveryAssessment(RecoveryDecision.NORMAL, ())


def source_coin_release_health(*, released: bool, evidence_reference: str) -> DependencyHealth:
    return DependencyHealth(
        EcologyDomain.SOURCE_COIN,
        DependencyState.HEALTHY if released else DependencyState.RELEASE_BLOCKED,
        evidence_reference,
    )
