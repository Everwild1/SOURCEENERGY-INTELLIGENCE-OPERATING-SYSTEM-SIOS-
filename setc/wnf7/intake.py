"""Strict component-facing intake for WNF-7 assessment submissions.

The intake boundary accepts portable JSON-compatible mappings, binds the
declared component to a trusted server-side component identity, and converts
the payload into the domain contracts used by :class:`WNF7ComponentGateway`.
Callers never supply a profile, adapter identity, consequence class, execution
command, or production flag; those values remain governed by the registry.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from .adapters import ComponentAssessmentSubmission, WNF7ComponentGateway
from .models import (
    ALL_DIMENSIONS,
    ComponentCode,
    Dimension,
    DimensionObservation,
    DimensionState,
    WNF7ContractError,
)
from .service import AssessmentReceipt


_SUBMISSION_FIELDS = frozenset(
    {
        "assessment_id",
        "pilot_code",
        "component_code",
        "operation_code",
        "subject_ref",
        "correlation_id",
        "idempotency_key",
        "observed_at",
        "authority_ref",
        "operational_reason",
        "interpretive_meaning",
        "observations",
        "metadata",
    }
)
_REQUIRED_SUBMISSION_FIELDS = frozenset(
    {
        "assessment_id",
        "component_code",
        "operation_code",
        "subject_ref",
        "correlation_id",
        "idempotency_key",
        "observed_at",
        "operational_reason",
        "observations",
    }
)
_OBSERVATION_FIELDS = frozenset(
    {
        "dimension",
        "status",
        "finding",
        "evidence_refs",
        "reviewed_at",
        "not_applicable_reason",
        "approving_authority_ref",
    }
)
_REQUIRED_OBSERVATION_FIELDS = frozenset(
    {"dimension", "status", "finding", "evidence_refs", "reviewed_at"}
)


def _mapping(name: str, value: Any) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise WNF7ContractError(f"{name} must be an object")
    if any(not isinstance(key, str) for key in value):
        raise WNF7ContractError(f"{name} keys must be strings")
    return value


def _strict_fields(
    name: str,
    value: Mapping[str, Any],
    *,
    allowed: frozenset[str],
    required: frozenset[str],
) -> None:
    unknown = sorted(set(value) - allowed)
    if unknown:
        raise WNF7ContractError(f"{name} contains prohibited fields: {', '.join(unknown)}")
    missing = sorted(required - set(value))
    if missing:
        raise WNF7ContractError(f"{name} is missing required fields: {', '.join(missing)}")


def _text(name: str, value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise WNF7ContractError(f"{name} must be a non-empty string")
    return value.strip()


def _optional_text(name: str, value: Any) -> str | None:
    if value is None:
        return None
    return _text(name, value)


def _timestamp(name: str, value: Any) -> datetime:
    raw = _text(name, value)
    try:
        parsed = datetime.fromisoformat(raw[:-1] + "+00:00" if raw.endswith("Z") else raw)
    except ValueError as exc:
        raise WNF7ContractError(f"{name} must be an ISO 8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise WNF7ContractError(f"{name} must include a timezone")
    return parsed


def _string_sequence(name: str, value: Any) -> tuple[str, ...]:
    if isinstance(value, (str, bytes)) or not isinstance(value, Sequence):
        raise WNF7ContractError(f"{name} must be an array of strings")
    return tuple(_text(f"{name}[{index}]", item) for index, item in enumerate(value))


def _observation(value: Any, index: int) -> DimensionObservation:
    name = f"observations[{index}]"
    payload = _mapping(name, value)
    _strict_fields(
        name,
        payload,
        allowed=_OBSERVATION_FIELDS,
        required=_REQUIRED_OBSERVATION_FIELDS,
    )
    try:
        dimension = Dimension(_text(f"{name}.dimension", payload["dimension"]))
    except ValueError as exc:
        raise WNF7ContractError(f"{name}.dimension is not a canonical WNF-7 dimension") from exc
    try:
        status = DimensionState(_text(f"{name}.status", payload["status"]))
    except ValueError as exc:
        raise WNF7ContractError(f"{name}.status is not a canonical WNF-7 state") from exc
    return DimensionObservation(
        dimension=dimension,
        status=status,
        finding=_text(f"{name}.finding", payload["finding"]),
        evidence_refs=_string_sequence(f"{name}.evidence_refs", payload["evidence_refs"]),
        reviewed_at=_timestamp(f"{name}.reviewed_at", payload["reviewed_at"]),
        not_applicable_reason=_optional_text(
            f"{name}.not_applicable_reason", payload.get("not_applicable_reason")
        ),
        approving_authority_ref=_optional_text(
            f"{name}.approving_authority_ref", payload.get("approving_authority_ref")
        ),
    )


@dataclass(frozen=True, slots=True)
class ParsedComponentSubmission:
    component_code: ComponentCode
    submission: ComponentAssessmentSubmission


def parse_component_submission(payload: Mapping[str, Any]) -> ParsedComponentSubmission:
    """Parse one untrusted portable submission using a strict fail-closed contract."""

    envelope = _mapping("submission", payload)
    _strict_fields(
        "submission",
        envelope,
        allowed=_SUBMISSION_FIELDS,
        required=_REQUIRED_SUBMISSION_FIELDS,
    )
    try:
        component_code = ComponentCode(_text("component_code", envelope["component_code"]))
    except ValueError as exc:
        raise WNF7ContractError("component_code is not a registered WNF-7 component") from exc

    raw_observations = envelope["observations"]
    if isinstance(raw_observations, (str, bytes)) or not isinstance(
        raw_observations, Sequence
    ):
        raise WNF7ContractError("observations must be an array")

    metadata = envelope.get("metadata", {})
    if not isinstance(metadata, Mapping):
        raise WNF7ContractError("metadata must be an object")

    pilot_code = _text("pilot_code", envelope.get("pilot_code", "PILOT-7D-001"))
    if pilot_code != "PILOT-7D-001":
        raise WNF7ContractError("component ingress is restricted to PILOT-7D-001")

    observations = tuple(
        _observation(observation, index)
        for index, observation in enumerate(raw_observations)
    )
    observed_dimensions = tuple(item.dimension for item in observations)
    if len(observed_dimensions) != 7 or set(observed_dimensions) != set(ALL_DIMENSIONS):
        raise WNF7ContractError("submission requires each of the seven dimensions exactly once")

    submission = ComponentAssessmentSubmission(
        assessment_id=_text("assessment_id", envelope["assessment_id"]),
        pilot_code=pilot_code,
        operation_code=_text("operation_code", envelope["operation_code"]),
        subject_ref=_text("subject_ref", envelope["subject_ref"]),
        correlation_id=_text("correlation_id", envelope["correlation_id"]),
        idempotency_key=_text("idempotency_key", envelope["idempotency_key"]),
        observed_at=_timestamp("observed_at", envelope["observed_at"]),
        authority_ref=_optional_text("authority_ref", envelope.get("authority_ref")),
        operational_reason=_text("operational_reason", envelope["operational_reason"]),
        interpretive_meaning=_optional_text(
            "interpretive_meaning", envelope.get("interpretive_meaning")
        ),
        observations=observations,
        metadata=dict(metadata),
    )
    return ParsedComponentSubmission(component_code=component_code, submission=submission)


class WNF7ComponentIngress:
    """Authenticated application ingress for all eight registered components.

    ``authenticated_component_code`` must come from trusted server-side routing
    or identity context.  It is intentionally separate from the untrusted
    envelope so a caller cannot submit an assessment on behalf of another
    component.
    """

    def __init__(self, gateway: WNF7ComponentGateway) -> None:
        self._gateway = gateway

    def assess(
        self,
        authenticated_component_code: ComponentCode | str,
        payload: Mapping[str, Any],
    ) -> AssessmentReceipt:
        try:
            authenticated_component = ComponentCode(authenticated_component_code)
        except (TypeError, ValueError) as exc:
            raise WNF7ContractError(
                "authenticated component is not registered for WNF-7"
            ) from exc
        parsed = parse_component_submission(payload)
        if parsed.component_code is not authenticated_component:
            raise WNF7ContractError(
                "authenticated component does not match the submitted component_code"
            )
        return self._gateway.assess(parsed.component_code, parsed.submission)


def assessment_result_envelope(receipt: AssessmentReceipt) -> dict[str, Any]:
    """Return the portable assessment envelope without persistence internals."""

    return receipt.result.to_dict()
