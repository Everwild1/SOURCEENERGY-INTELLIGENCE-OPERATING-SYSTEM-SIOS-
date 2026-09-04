"""Deterministic WNF-7 aggregation with fail-closed authority semantics."""

from __future__ import annotations

import hashlib
import json
from typing import Any

from .bindings import component_binding
from .models import (
    ALL_DIMENSIONS,
    AssessmentRequest,
    AssessmentResult,
    AutomatedState,
    DecisionEligibility,
    Dimension,
    DimensionResult,
    DimensionState,
    WNF7ContractError,
)


EVALUATOR_VERSION = "wnf7-runtime-1.0"


def _canonical_sha256(payload: Any) -> str:
    try:
        encoded = json.dumps(
            payload,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise WNF7ContractError("assessment metadata must be JSON serializable") from exc
    return hashlib.sha256(encoded).hexdigest()


def evaluate_assessment(request: AssessmentRequest) -> AssessmentResult:
    """Evaluate all seven dimensions without producing executable authority.

    Dimension findings are supplied by governed component adapters. This kernel
    binds them to the component's canonical controls, applies the cross-ecosystem
    fail-closed rules, and emits a deterministic advisory posture.
    """

    binding = component_binding(request.component_code)
    if request.profile_code != binding.profile_code:
        raise WNF7ContractError(
            f"profile {request.profile_code} does not govern {request.component_code.value}"
        )

    by_dimension = {item.dimension: item for item in request.ordered_observations()}
    results: list[DimensionResult] = []
    for dimension in ALL_DIMENSIONS:
        observation = by_dimension[dimension]
        status = observation.status
        finding = observation.finding

        # Fear is the authority gate. Uncertainty, inapplicability, or a claimed
        # pass without a resolvable authority reference is a hard block.
        if dimension is Dimension.FEAR and (
            status is not DimensionState.PASS or request.authority_ref is None
        ):
            status = DimensionState.BLOCKED
            if request.authority_ref is None:
                finding = f"{finding} Authority reference missing; WNF-7 failed closed."

        rule = binding.dimensions[dimension]
        results.append(
            DimensionResult(
                dimension=dimension,
                status=status,
                finding=finding,
                evidence_refs=observation.evidence_refs,
                control_refs=(rule.control_ref,),
                owner_role=rule.owner_role,
                reviewed_at=observation.reviewed_at,
                not_applicable_reason=observation.not_applicable_reason,
                approving_authority_ref=observation.approving_authority_ref,
            )
        )

    blocked = tuple(item.dimension for item in results if item.status is DimensionState.BLOCKED)
    review = tuple(
        item.dimension
        for item in results
        if item.status in {DimensionState.REVIEW, DimensionState.NOT_APPLICABLE}
    )

    if blocked:
        automated_state = AutomatedState.BLOCKED
        eligibility = DecisionEligibility.NOT_ELIGIBLE
    elif review:
        automated_state = AutomatedState.REVIEW
        eligibility = DecisionEligibility.SIMULATION_ONLY
    else:
        automated_state = AutomatedState.PASS
        eligibility = DecisionEligibility.ELIGIBLE_FOR_HUMAN_DECISION

    unresolved_roles = [
        item.owner_role
        for item in results
        if item.dimension in set(blocked + review)
    ]
    reviewer_roles = tuple(dict.fromkeys(unresolved_roles or ("KNOWLEDGE_GOVERNOR",)))
    input_sha256 = _canonical_sha256(request.to_input_dict())
    output_core = {
        "assessment_id": request.assessment_id,
        "component_code": request.component_code.value,
        "profile_code": request.profile_code,
        "observed_at": request.to_input_dict()["observed_at"],
        "dimension_results": [item.to_dict() for item in results],
        "automated_state": automated_state.value,
        "decision_eligibility": eligibility.value,
        "blocking_dimensions": [item.value for item in blocked],
        "review_dimensions": [item.value for item in review],
        "recommended_reviewer_roles": list(reviewer_roles),
        "human_review_required": True,
        "execution_command": None,
        "input_sha256": input_sha256,
        "evaluator_version": EVALUATOR_VERSION,
    }

    return AssessmentResult(
        assessment_id=request.assessment_id,
        component_code=request.component_code,
        profile_code=request.profile_code,
        observed_at=request.observed_at,
        dimension_results=tuple(results),
        automated_state=automated_state,
        decision_eligibility=eligibility,
        blocking_dimensions=blocked,
        review_dimensions=review,
        recommended_reviewer_roles=reviewer_roles,
        input_sha256=input_sha256,
        output_sha256=_canonical_sha256(output_core),
        evaluator_version=EVALUATOR_VERSION,
    )
