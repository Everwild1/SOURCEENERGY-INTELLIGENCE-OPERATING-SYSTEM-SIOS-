"""Versioned component-facing adapters for the shared WNF-7 kernel.

Every adapter prepares an evidence-backed assessment request.  No adapter in
this module executes a command, mutates a component domain, or grants release
authority.  The operation registry fixes the consequence class so a caller
cannot downgrade a consequential review to a lower-impact label.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from types import MappingProxyType
from typing import Any, Mapping, Protocol

from .bindings import component_binding
from .models import (
    ALL_COMPONENTS,
    AssessmentRequest,
    ComponentCode,
    ConsequenceClass,
    DimensionObservation,
    WNF7ContractError,
)


ADAPTER_VERSION = "wnf7-adapter-1.0"

_FORBIDDEN_METADATA_KEYS = frozenset(
    {
        "command",
        "execution_command",
        "external_side_effect",
        "external_side_effects",
        "ledger_mutation",
        "password",
        "private_key",
        "raw_banking_data",
        "secret",
        "service_role",
        "service_role_key",
    }
)
_RESERVED_METADATA_KEYS = frozenset({"wnf7_adapter"})


def _required_text(name: str, value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise WNF7ContractError(f"{name} is required")
    return normalized


def _normalized_key(value: str) -> str:
    return value.strip().lower().replace("-", "_").replace(" ", "_")


def _assert_safe_metadata(value: Any, path: str = "metadata") -> None:
    if isinstance(value, Mapping):
        for raw_key, child in value.items():
            if not isinstance(raw_key, str) or not raw_key.strip():
                raise WNF7ContractError(f"{path} keys must be non-empty strings")
            key = _normalized_key(raw_key)
            if key in _FORBIDDEN_METADATA_KEYS or key.endswith("_secret"):
                raise WNF7ContractError(f"{path}.{raw_key} is prohibited in WNF-7 metadata")
            _assert_safe_metadata(child, f"{path}.{raw_key}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _assert_safe_metadata(child, f"{path}[{index}]")


@dataclass(frozen=True, slots=True)
class AdapterOperation:
    operation_code: str
    consequence_class: ConsequenceClass
    purpose: str

    def __post_init__(self) -> None:
        object.__setattr__(self, "operation_code", _required_text("operation_code", self.operation_code))
        object.__setattr__(self, "consequence_class", ConsequenceClass(self.consequence_class))
        object.__setattr__(self, "purpose", _required_text("purpose", self.purpose))


@dataclass(frozen=True, slots=True)
class ComponentAdapterDefinition:
    adapter_code: str
    component_code: ComponentCode
    profile_code: str
    adapter_version: str
    runtime_entrypoint: str
    operations: Mapping[str, AdapterOperation]
    lifecycle_state: str = "PILOT"
    production_authorized: bool = False
    external_side_effects: bool = False

    def __post_init__(self) -> None:
        object.__setattr__(self, "adapter_code", _required_text("adapter_code", self.adapter_code))
        object.__setattr__(self, "component_code", ComponentCode(self.component_code))
        object.__setattr__(self, "profile_code", _required_text("profile_code", self.profile_code))
        object.__setattr__(self, "adapter_version", _required_text("adapter_version", self.adapter_version))
        object.__setattr__(self, "runtime_entrypoint", _required_text("runtime_entrypoint", self.runtime_entrypoint))
        operations = dict(self.operations)
        if len(operations) != 3 or set(operations) != {
            operation.operation_code for operation in operations.values()
        }:
            raise WNF7ContractError("each component adapter requires three keyed operations")
        object.__setattr__(self, "operations", MappingProxyType(operations))
        if self.lifecycle_state != "PILOT":
            raise WNF7ContractError("WNF-7 component adapters are pilot-only")
        if self.production_authorized or self.external_side_effects:
            raise WNF7ContractError("WNF-7 adapters cannot authorize production or external side effects")
        binding = component_binding(self.component_code)
        if self.profile_code != binding.profile_code:
            raise WNF7ContractError("adapter profile does not match the component binding")

    def operation(self, operation_code: str) -> AdapterOperation:
        try:
            return self.operations[operation_code]
        except KeyError as exc:
            raise WNF7ContractError(
                f"unsupported {self.component_code.value} WNF-7 operation: {operation_code}"
            ) from exc


def _operation(
    operation_code: str,
    consequence_class: ConsequenceClass,
    purpose: str,
) -> AdapterOperation:
    return AdapterOperation(operation_code, consequence_class, purpose)


def _definition(
    component_code: ComponentCode,
    *operations: AdapterOperation,
) -> ComponentAdapterDefinition:
    binding = component_binding(component_code)
    return ComponentAdapterDefinition(
        adapter_code=f"WNF7-ADAPTER-{component_code.value}-001",
        component_code=component_code,
        profile_code=binding.profile_code,
        adapter_version=ADAPTER_VERSION,
        runtime_entrypoint=f"setc.wnf7.adapters:{component_code.value}_ADAPTER",
        operations={operation.operation_code: operation for operation in operations},
    )


_DEFINITIONS = (
    _definition(
        ComponentCode.SETC,
        _operation("AUTHORITY_REVIEW", ConsequenceClass.OPERATIONAL, "Resolve governing authority and scope."),
        _operation("POLICY_DECISION", ConsequenceClass.OPERATIONAL, "Evaluate a bounded SETC policy decision."),
        _operation("RELEASE_GATE_REVIEW", ConsequenceClass.CONSEQUENTIAL, "Prepare a release posture for accountable human ruling."),
    ),
    _definition(
        ComponentCode.SOURCECUBE,
        _operation("CONTEXT_CLASSIFICATION", ConsequenceClass.INFORMATIONAL, "Classify governed context and provenance."),
        _operation("EVIDENCE_SYNTHESIS", ConsequenceClass.ADVISORY, "Synthesize evidence with uncertainty and contradiction visible."),
        _operation("ADVISORY_PLAN", ConsequenceClass.ADVISORY, "Prepare a non-executing orchestration plan."),
    ),
    _definition(
        ComponentCode.CODEX_VERITAS,
        _operation("CLAIM_ASSESSMENT", ConsequenceClass.INFORMATIONAL, "Classify a claim and its attributable support."),
        _operation("CONTRADICTION_REVIEW", ConsequenceClass.ADVISORY, "Assess contradiction and supersession posture."),
        _operation("PUBLICATION_REVIEW", ConsequenceClass.ADVISORY, "Prepare a claim for governed human publication review."),
    ),
    _definition(
        ComponentCode.SOURCEONE,
        _operation("HUMAN_ACTION_REVIEW", ConsequenceClass.OPERATIONAL, "Assess a human-facing governed action."),
        _operation("APPROVAL_CONTEXT", ConsequenceClass.CONSEQUENTIAL, "Present complete context for an accountable approval."),
        _operation("OUTCOME_EXPLANATION", ConsequenceClass.INFORMATIONAL, "Explain a governed outcome and its evidence."),
    ),
    _definition(
        ComponentCode.SIOS,
        _operation("WORKFLOW_TRANSITION_REVIEW", ConsequenceClass.OPERATIONAL, "Assess a bounded state transition."),
        _operation("CROSS_DOMAIN_HANDOFF", ConsequenceClass.OPERATIONAL, "Assess a governed cross-domain handoff."),
        _operation("RELEASE_READINESS", ConsequenceClass.CONSEQUENTIAL, "Prepare system release readiness for human authorization."),
    ),
    _definition(
        ComponentCode.SIDEKICK_OEL,
        _operation("WORK_ITEM_INTAKE", ConsequenceClass.OPERATIONAL, "Assess delegated work intake and acceptance criteria."),
        _operation("DELEGATION_REVIEW", ConsequenceClass.OPERATIONAL, "Assess role, scope, control level, and expiry."),
        _operation("OUTCOME_REVIEW", ConsequenceClass.ADVISORY, "Review evidence and exceptions from completed work."),
    ),
    _definition(
        ComponentCode.SOURCECOIN,
        _operation("ECONOMIC_ELIGIBILITY", ConsequenceClass.ADVISORY, "Assess economic eligibility without ledger mutation."),
        _operation("TRANSFER_ELIGIBILITY", ConsequenceClass.CONSEQUENTIAL, "Assess transfer eligibility without authorizing transfer."),
        _operation("SETTLEMENT_ELIGIBILITY", ConsequenceClass.CONSEQUENTIAL, "Assess settlement eligibility without conferring finality."),
    ),
    _definition(
        ComponentCode.SOURCEBLOCK,
        _operation("LIFECYCLE_GATE", ConsequenceClass.OPERATIONAL, "Assess a bounded SourceBlock lifecycle transition."),
        _operation("VALUE_EVIDENCE_REVIEW", ConsequenceClass.ADVISORY, "Review value evidence without manufacturing valuation."),
        _operation("CLOSURE_REVIEW", ConsequenceClass.CONSEQUENTIAL, "Prepare closure evidence without asserting external finality."),
    ),
)


ADAPTER_DEFINITIONS: Mapping[ComponentCode, ComponentAdapterDefinition] = MappingProxyType(
    {definition.component_code: definition for definition in _DEFINITIONS}
)


def component_adapter_definition(
    component_code: ComponentCode | str,
) -> ComponentAdapterDefinition:
    try:
        return ADAPTER_DEFINITIONS[ComponentCode(component_code)]
    except (KeyError, ValueError) as exc:
        raise WNF7ContractError(f"unsupported WNF-7 component adapter: {component_code}") from exc


@dataclass(frozen=True, slots=True)
class ComponentAssessmentSubmission:
    assessment_id: str
    operation_code: str
    subject_ref: str
    correlation_id: str
    idempotency_key: str
    observed_at: datetime
    operational_reason: str
    observations: tuple[DimensionObservation, ...]
    authority_ref: str | None = None
    interpretive_meaning: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    pilot_code: str = "PILOT-7D-001"
    execution_command: Any | None = None
    external_side_effect_requested: bool = False

    def __post_init__(self) -> None:
        object.__setattr__(self, "operation_code", _required_text("operation_code", self.operation_code))
        if self.execution_command is not None:
            raise WNF7ContractError("WNF-7 adapter submissions cannot carry an execution command")
        if self.external_side_effect_requested:
            raise WNF7ContractError("WNF-7 adapter submissions cannot request an external side effect")
        metadata = dict(self.metadata)
        _assert_safe_metadata(metadata)
        if _RESERVED_METADATA_KEYS.intersection(_normalized_key(key) for key in metadata):
            raise WNF7ContractError("wnf7_adapter metadata is reserved for the trusted adapter")
        object.__setattr__(self, "metadata", metadata)
        object.__setattr__(self, "observations", tuple(self.observations))


class AssessmentServicePort(Protocol):
    def assess(self, request: AssessmentRequest) -> Any: ...


@dataclass(frozen=True, slots=True)
class ComponentAssessmentAdapter:
    definition: ComponentAdapterDefinition

    @property
    def may_execute(self) -> bool:
        return False

    @property
    def default_operation_code(self) -> str:
        return next(iter(self.definition.operations))

    def prepare(self, submission: ComponentAssessmentSubmission) -> AssessmentRequest:
        operation = self.definition.operation(submission.operation_code)
        metadata = dict(submission.metadata)
        metadata["wnf7_adapter"] = {
            "adapter_code": self.definition.adapter_code,
            "adapter_version": self.definition.adapter_version,
            "operation_code": operation.operation_code,
            "control_mode": "ASSESSMENT_ONLY",
            "external_side_effects": False,
            "production_authorized": False,
        }
        return AssessmentRequest(
            assessment_id=submission.assessment_id,
            component_code=self.definition.component_code,
            profile_code=self.definition.profile_code,
            adapter_code=self.definition.adapter_code,
            adapter_version=self.definition.adapter_version,
            operation_code=operation.operation_code,
            subject_ref=submission.subject_ref,
            correlation_id=submission.correlation_id,
            idempotency_key=submission.idempotency_key,
            consequence_class=operation.consequence_class,
            observed_at=submission.observed_at,
            operational_reason=submission.operational_reason,
            observations=submission.observations,
            authority_ref=submission.authority_ref,
            interpretive_meaning=submission.interpretive_meaning,
            metadata=metadata,
            pilot_code=submission.pilot_code,
        )

    def assess(
        self,
        service: AssessmentServicePort,
        submission: ComponentAssessmentSubmission,
    ) -> Any:
        return service.assess(self.prepare(submission))


COMPONENT_ADAPTERS: Mapping[ComponentCode, ComponentAssessmentAdapter] = MappingProxyType(
    {
        component_code: ComponentAssessmentAdapter(definition)
        for component_code, definition in ADAPTER_DEFINITIONS.items()
    }
)

SETC_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SETC]
SOURCECUBE_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SOURCECUBE]
CODEX_VERITAS_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.CODEX_VERITAS]
SOURCEONE_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SOURCEONE]
SIOS_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SIOS]
SIDEKICK_OEL_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SIDEKICK_OEL]
SOURCECOIN_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SOURCECOIN]
SOURCEBLOCK_ADAPTER = COMPONENT_ADAPTERS[ComponentCode.SOURCEBLOCK]


def component_adapter(component_code: ComponentCode | str) -> ComponentAssessmentAdapter:
    try:
        return COMPONENT_ADAPTERS[ComponentCode(component_code)]
    except (KeyError, ValueError) as exc:
        raise WNF7ContractError(f"unsupported WNF-7 component adapter: {component_code}") from exc


class WNF7ComponentGateway:
    """Single trusted entry point used by every registered component adapter."""

    def __init__(self, service: AssessmentServicePort) -> None:
        self._service = service

    def assess(
        self,
        component_code: ComponentCode | str,
        submission: ComponentAssessmentSubmission,
    ) -> Any:
        return component_adapter(component_code).assess(self._service, submission)


if set(ADAPTER_DEFINITIONS) != set(ALL_COMPONENTS):
    raise RuntimeError("WNF-7 adapter registry does not cover every ecosystem component")
