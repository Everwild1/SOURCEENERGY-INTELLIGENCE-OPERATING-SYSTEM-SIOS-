"""Application service for deterministic, idempotent WNF-7 assessment."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, Protocol

from .evaluator import evaluate_assessment
from .models import AssessmentRequest, AssessmentResult, WNF7ContractError


class AssessmentRepository(Protocol):
    def find_by_idempotency(
        self,
        component_code: str,
        idempotency_key: str,
    ) -> Mapping[str, Any] | None: ...

    def append(
        self,
        request: AssessmentRequest,
        result: AssessmentResult,
    ) -> Mapping[str, Any]: ...


@dataclass(frozen=True, slots=True)
class AssessmentReceipt:
    result: AssessmentResult
    persisted_record: Mapping[str, Any]
    replayed: bool

    @property
    def may_execute(self) -> bool:
        return False


class WNF7AssessmentService:
    def __init__(self, repository: AssessmentRepository) -> None:
        self._repository = repository

    def assess(self, request: AssessmentRequest) -> AssessmentReceipt:
        result = evaluate_assessment(request)
        existing = self._repository.find_by_idempotency(
            request.component_code.value,
            request.idempotency_key,
        )
        if existing is not None:
            if existing.get("input_sha256") != result.input_sha256:
                raise WNF7ContractError(
                    "idempotency key already exists for a different assessment input"
                )
            if existing.get("output_sha256") != result.output_sha256:
                raise WNF7ContractError(
                    "persisted WNF-7 output does not match deterministic evaluation"
                )
            return AssessmentReceipt(result=result, persisted_record=existing, replayed=True)

        record = self._repository.append(request, result)
        return AssessmentReceipt(result=result, persisted_record=record, replayed=False)
