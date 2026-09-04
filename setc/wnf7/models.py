"""Domain contracts for the WNF-7 SourceEnergy assessment boundary.

The contracts describe evidence-backed governance assessments. They never carry
an executable command or confer spiritual, legal, financial, regulatory,
custody, settlement, or production authority.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import StrEnum
from typing import Any, Mapping, Sequence


class WNF7ContractError(ValueError):
    """Raised when an assessment violates the WNF-7 contract."""


class Dimension(StrEnum):
    FEAR = "FEAR"
    PRESENCE = "PRESENCE"
    WISDOM = "WISDOM"
    KNOWLEDGE = "KNOWLEDGE"
    UNDERSTANDING = "UNDERSTANDING"
    COUNSEL = "COUNSEL"
    MIGHT_POWER = "MIGHT_POWER"


class DimensionState(StrEnum):
    PASS = "PASS"
    REVIEW = "REVIEW"
    BLOCKED = "BLOCKED"
    NOT_APPLICABLE = "NOT_APPLICABLE"


class AutomatedState(StrEnum):
    PASS = "PASS"
    REVIEW = "REVIEW"
    BLOCKED = "BLOCKED"


class DecisionEligibility(StrEnum):
    ELIGIBLE_FOR_HUMAN_DECISION = "ELIGIBLE_FOR_HUMAN_DECISION"
    SIMULATION_ONLY = "SIMULATION_ONLY"
    NOT_ELIGIBLE = "NOT_ELIGIBLE"


class ConsequenceClass(StrEnum):
    INFORMATIONAL = "INFORMATIONAL"
    ADVISORY = "ADVISORY"
    OPERATIONAL = "OPERATIONAL"
    CONSEQUENTIAL = "CONSEQUENTIAL"


class ComponentCode(StrEnum):
    SETC = "SETC"
    SOURCECUBE = "SOURCECUBE"
    CODEX_VERITAS = "CODEX_VERITAS"
    SOURCEONE = "SOURCEONE"
    SIOS = "SIOS"
    SIDEKICK_OEL = "SIDEKICK_OEL"
    SOURCECOIN = "SOURCECOIN"
    SOURCEBLOCK = "SOURCEBLOCK"


ALL_DIMENSIONS = tuple(Dimension)
ALL_COMPONENTS = tuple(ComponentCode)


def _required_text(name: str, value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise WNF7ContractError(f"{name} is required")
    return normalized


def _unique_texts(name: str, values: Sequence[str]) -> tuple[str, ...]:
    normalized = tuple(_required_text(name, value) for value in values)
    if not normalized:
        raise WNF7ContractError(f"{name} requires at least one reference")
    if len(set(normalized)) != len(normalized):
        raise WNF7ContractError(f"{name} references must be unique")
    return normalized


def utc_timestamp(value: datetime) -> str:
    if value.tzinfo is None or value.utcoffset() is None:
        raise WNF7ContractError("timestamps must be timezone-aware")
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass(frozen=True, slots=True)
class DimensionObservation:
    dimension: Dimension
    status: DimensionState
    finding: str
    evidence_refs: tuple[str, ...]
    reviewed_at: datetime
    not_applicable_reason: str | None = None
    approving_authority_ref: str | None = None

    def __post_init__(self) -> None:
        object.__setattr__(self, "dimension", Dimension(self.dimension))
        object.__setattr__(self, "status", DimensionState(self.status))
        object.__setattr__(self, "finding", _required_text("finding", self.finding))
        object.__setattr__(self, "evidence_refs", _unique_texts("evidence_refs", self.evidence_refs))
        utc_timestamp(self.reviewed_at)
        if self.status is DimensionState.NOT_APPLICABLE:
            if not self.not_applicable_reason or not self.not_applicable_reason.strip():
                raise WNF7ContractError("NOT_APPLICABLE requires a reason")
            if not self.approving_authority_ref or not self.approving_authority_ref.strip():
                raise WNF7ContractError("NOT_APPLICABLE requires an approving authority reference")

    def to_input_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "dimension": self.dimension.value,
            "status": self.status.value,
            "finding": self.finding,
            "evidence_refs": list(self.evidence_refs),
            "reviewed_at": utc_timestamp(self.reviewed_at),
        }
        if self.not_applicable_reason:
            payload["not_applicable_reason"] = self.not_applicable_reason.strip()
        if self.approving_authority_ref:
            payload["approving_authority_ref"] = self.approving_authority_ref.strip()
        return payload


@dataclass(frozen=True, slots=True)
class AssessmentRequest:
    assessment_id: str
    component_code: ComponentCode
    profile_code: str
    adapter_code: str
    adapter_version: str
    operation_code: str
    subject_ref: str
    correlation_id: str
    idempotency_key: str
    consequence_class: ConsequenceClass
    observed_at: datetime
    operational_reason: str
    observations: tuple[DimensionObservation, ...]
    authority_ref: str | None = None
    interpretive_meaning: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    pilot_code: str = "PILOT-7D-001"

    def __post_init__(self) -> None:
        object.__setattr__(self, "component_code", ComponentCode(self.component_code))
        object.__setattr__(self, "consequence_class", ConsequenceClass(self.consequence_class))
        for name in (
            "assessment_id",
            "profile_code",
            "adapter_code",
            "adapter_version",
            "operation_code",
            "subject_ref",
            "correlation_id",
            "idempotency_key",
            "operational_reason",
            "pilot_code",
        ):
            object.__setattr__(self, name, _required_text(name, getattr(self, name)))
        if not self.assessment_id.startswith("WNF7-"):
            raise WNF7ContractError("assessment_id must start with WNF7-")
        utc_timestamp(self.observed_at)
        observations = tuple(self.observations)
        object.__setattr__(self, "observations", observations)
        observed_dimensions = tuple(item.dimension for item in observations)
        if len(observed_dimensions) != 7 or set(observed_dimensions) != set(ALL_DIMENSIONS):
            raise WNF7ContractError("an assessment requires each of the seven dimensions exactly once")
        if len(set(observed_dimensions)) != len(observed_dimensions):
            raise WNF7ContractError("dimension observations must be unique")
        if self.authority_ref is not None:
            object.__setattr__(self, "authority_ref", _required_text("authority_ref", self.authority_ref))
        if self.interpretive_meaning is not None:
            object.__setattr__(
                self,
                "interpretive_meaning",
                _required_text("interpretive_meaning", self.interpretive_meaning),
            )
        metadata = dict(self.metadata)
        object.__setattr__(self, "metadata", metadata)

    def ordered_observations(self) -> tuple[DimensionObservation, ...]:
        by_dimension = {item.dimension: item for item in self.observations}
        return tuple(by_dimension[dimension] for dimension in ALL_DIMENSIONS)

    def to_input_dict(self) -> dict[str, Any]:
        return {
            "assessment_id": self.assessment_id,
            "pilot_code": self.pilot_code,
            "component_code": self.component_code.value,
            "profile_code": self.profile_code,
            "adapter_code": self.adapter_code,
            "adapter_version": self.adapter_version,
            "operation_code": self.operation_code,
            "subject_ref": self.subject_ref,
            "correlation_id": self.correlation_id,
            "idempotency_key": self.idempotency_key,
            "consequence_class": self.consequence_class.value,
            "observed_at": utc_timestamp(self.observed_at),
            "authority_ref": self.authority_ref,
            "operational_reason": self.operational_reason,
            "interpretive_meaning": self.interpretive_meaning,
            "observations": [item.to_input_dict() for item in self.ordered_observations()],
            "metadata": dict(self.metadata),
        }


@dataclass(frozen=True, slots=True)
class DimensionResult:
    dimension: Dimension
    status: DimensionState
    finding: str
    evidence_refs: tuple[str, ...]
    control_refs: tuple[str, ...]
    owner_role: str
    reviewed_at: datetime
    not_applicable_reason: str | None = None
    approving_authority_ref: str | None = None

    def to_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "dimension": self.dimension.value,
            "status": self.status.value,
            "finding": self.finding,
            "evidence_refs": list(self.evidence_refs),
            "control_refs": list(self.control_refs),
            "owner_role": self.owner_role,
            "reviewed_at": utc_timestamp(self.reviewed_at),
        }
        if self.not_applicable_reason:
            payload["not_applicable_reason"] = self.not_applicable_reason
        if self.approving_authority_ref:
            payload["approving_authority_ref"] = self.approving_authority_ref
        return payload


@dataclass(frozen=True, slots=True)
class AssessmentResult:
    assessment_id: str
    component_code: ComponentCode
    profile_code: str
    adapter_code: str
    adapter_version: str
    operation_code: str
    consequence_class: ConsequenceClass
    observed_at: datetime
    dimension_results: tuple[DimensionResult, ...]
    automated_state: AutomatedState
    decision_eligibility: DecisionEligibility
    blocking_dimensions: tuple[Dimension, ...]
    review_dimensions: tuple[Dimension, ...]
    recommended_reviewer_roles: tuple[str, ...]
    input_sha256: str
    output_sha256: str
    evaluator_version: str
    human_review_required: bool = True
    execution_command: None = None

    @property
    def may_execute(self) -> bool:
        return False

    def to_dict(self) -> dict[str, Any]:
        return {
            "assessment_id": self.assessment_id,
            "component_code": self.component_code.value,
            "profile_code": self.profile_code,
            "adapter_code": self.adapter_code,
            "adapter_version": self.adapter_version,
            "operation_code": self.operation_code,
            "consequence_class": self.consequence_class.value,
            "observed_at": utc_timestamp(self.observed_at),
            "dimensions": [item.dimension.value for item in self.dimension_results],
            "dimension_results": [item.to_dict() for item in self.dimension_results],
            "automated_state": self.automated_state.value,
            "decision_eligibility": self.decision_eligibility.value,
            "blocking_dimensions": [item.value for item in self.blocking_dimensions],
            "review_dimensions": [item.value for item in self.review_dimensions],
            "recommended_reviewer_roles": list(self.recommended_reviewer_roles),
            "human_review_required": self.human_review_required,
            "execution_command": self.execution_command,
            "input_sha256": self.input_sha256,
            "output_sha256": self.output_sha256,
            "evaluator_version": self.evaluator_version,
        }
