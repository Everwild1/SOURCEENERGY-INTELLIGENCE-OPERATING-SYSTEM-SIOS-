"""Organizational resilience and continuity primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ContinuityState(StrEnum):
    DRAFT = "DRAFT"
    APPROVED = "APPROVED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    RETIRED = "RETIRED"


class DisruptionState(StrEnum):
    DECLARED = "DECLARED"
    ACTIVE_RESPONSE = "ACTIVE_RESPONSE"
    RECOVERING = "RECOVERING"
    RECOVERED = "RECOVERED"
    CLOSED = "CLOSED"


class ExerciseOutcome(StrEnum):
    NOT_MET = "NOT_MET"
    PARTIALLY_MET = "PARTIALLY_MET"
    MET = "MET"
    EXCEEDED = "EXCEEDED"


@dataclass(frozen=True, slots=True)
class ContinuityPlan:
    plan_id: SETCIdentifier
    organization_id: SETCIdentifier
    name: str
    version: str
    state: ContinuityState = ContinuityState.DRAFT
    policy_reference: str | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip():
            raise ValueError("continuity plan requires name and version")
        if self.policy_reference is not None and not self.policy_reference.strip():
            raise ValueError("policy_reference cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("continuity plan evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class CriticalServiceDependency:
    dependency_id: SETCIdentifier
    organization_id: SETCIdentifier
    service_reference: str
    dependency_organization_id: SETCIdentifier | None = None
    dependency_reference: str | None = None
    criticality: str = "CRITICAL"

    def __post_init__(self) -> None:
        if not self.service_reference.strip() or not self.criticality.strip():
            raise ValueError("critical service dependency requires service and criticality")
        if self.dependency_reference is not None and not self.dependency_reference.strip():
            raise ValueError("dependency_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class RecoveryObjective:
    objective_id: SETCIdentifier
    plan_id: SETCIdentifier
    service_reference: str
    recovery_time_minutes: int
    recovery_point_minutes: int | None = None

    def __post_init__(self) -> None:
        if not self.service_reference.strip():
            raise ValueError("service_reference cannot be blank")
        if self.recovery_time_minutes <= 0:
            raise ValueError("recovery_time_minutes must be positive")
        if self.recovery_point_minutes is not None and self.recovery_point_minutes < 0:
            raise ValueError("recovery_point_minutes cannot be negative")


@dataclass(frozen=True, slots=True)
class DisruptionDeclaration:
    disruption_id: SETCIdentifier
    organization_id: SETCIdentifier
    disruption_type: str
    state: DisruptionState = DisruptionState.DECLARED
    declared_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.disruption_type.strip():
            raise ValueError("disruption_type cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ContinuityActivation:
    activation_id: SETCIdentifier
    disruption_id: SETCIdentifier
    plan_id: SETCIdentifier
    activated_at: datetime
    activated_by_organization_id: SETCIdentifier
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.evidence_reference.strip():
            raise ValueError("continuity activation requires evidence")


@dataclass(frozen=True, slots=True)
class RecoveryEvidence:
    recovery_id: SETCIdentifier
    disruption_id: SETCIdentifier
    service_reference: str
    recovered_at: datetime
    evidence_reference: str
    measured_recovery_minutes: int | None = None

    def __post_init__(self) -> None:
        if not self.service_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("recovery evidence requires service and evidence reference")
        if self.measured_recovery_minutes is not None and self.measured_recovery_minutes < 0:
            raise ValueError("measured_recovery_minutes cannot be negative")


@dataclass(frozen=True, slots=True)
class ResilienceExercise:
    exercise_id: SETCIdentifier
    organization_id: SETCIdentifier
    plan_id: SETCIdentifier
    scenario: str
    conducted_at: datetime
    outcome: ExerciseOutcome
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.scenario.strip():
            raise ValueError("exercise scenario cannot be blank")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("exercise evidence references cannot contain blanks")
        if self.outcome in {ExerciseOutcome.MET, ExerciseOutcome.EXCEEDED} and not self.evidence_references:
            raise ValueError("successful resilience exercises require evidence")


@dataclass(frozen=True, slots=True)
class ResilienceCorrectiveAction:
    action_id: SETCIdentifier
    organization_id: SETCIdentifier
    source_reference: str
    action: str
    owner_organization_id: SETCIdentifier
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.source_reference.strip() or not self.action.strip():
            raise ValueError("corrective action requires source and action text")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
