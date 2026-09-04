"""Trusted server-side Supabase adapter for append-only WNF-7 assessments.

The adapter receives a preconfigured server client. It never reads credentials,
constructs a public client, exposes secret/service-role material, or provides an
update/delete surface.
"""

from __future__ import annotations

from typing import Any, Mapping, Protocol

from .models import AssessmentRequest, AssessmentResult, WNF7ContractError, utc_timestamp


class QueryResult(Protocol):
    data: Any


class QueryBuilder(Protocol):
    def select(self, columns: str = "*") -> "QueryBuilder": ...
    def eq(self, column: str, value: Any) -> "QueryBuilder": ...
    def insert(self, payload: Mapping[str, Any]) -> "QueryBuilder": ...
    def execute(self) -> QueryResult: ...


class SchemaClient(Protocol):
    def table(self, name: str) -> QueryBuilder: ...


class SupabaseLikeClient(Protocol):
    def schema(self, name: str) -> SchemaClient: ...


class SupabaseWNF7Repository:
    """Allow-listed WNF-7 persistence for a trusted server environment."""

    TABLE = "assessment_records"

    def __init__(self, client: SupabaseLikeClient) -> None:
        self._wnf7 = client.schema("wnf7")

    def find_by_idempotency(
        self,
        component_code: str,
        idempotency_key: str,
    ) -> Mapping[str, Any] | None:
        result = (
            self._wnf7.table(self.TABLE)
            .select("*")
            .eq("component_code", component_code)
            .eq("idempotency_key", idempotency_key)
            .execute()
        )
        rows = list(result.data or [])
        if len(rows) > 1:
            raise WNF7ContractError("WNF-7 idempotency lookup returned multiple records")
        return rows[0] if rows else None

    def append(
        self,
        request: AssessmentRequest,
        result: AssessmentResult,
    ) -> Mapping[str, Any]:
        if result.assessment_id != request.assessment_id:
            raise WNF7ContractError("assessment result does not match request")
        if result.component_code is not request.component_code:
            raise WNF7ContractError("assessment component does not match request")
        if result.profile_code != request.profile_code:
            raise WNF7ContractError("assessment profile does not match request")
        if (
            result.adapter_code != request.adapter_code
            or result.adapter_version != request.adapter_version
            or result.operation_code != request.operation_code
            or result.consequence_class is not request.consequence_class
        ):
            raise WNF7ContractError("assessment adapter identity does not match request")
        if not result.human_review_required or result.execution_command is not None:
            raise WNF7ContractError("WNF-7 persistence requires human review and a null command")

        payload = {
            "assessment_id": request.assessment_id,
            "pilot_code": request.pilot_code,
            "component_code": request.component_code.value,
            "profile_code": request.profile_code,
            "adapter_code": request.adapter_code,
            "adapter_version": request.adapter_version,
            "operation_code": request.operation_code,
            "subject_ref": request.subject_ref,
            "correlation_id": request.correlation_id,
            "idempotency_key": request.idempotency_key,
            "consequence_class": request.consequence_class.value,
            "observed_at": utc_timestamp(request.observed_at),
            "authority_ref": request.authority_ref,
            "operational_reason": request.operational_reason,
            "interpretive_meaning": request.interpretive_meaning,
            "dimension_results": [item.to_dict() for item in result.dimension_results],
            "human_review_required": True,
            "execution_command": None,
            "input_sha256": result.input_sha256,
            "output_sha256": result.output_sha256,
            "evaluator_version": result.evaluator_version,
            "metadata": dict(request.metadata),
        }
        response = self._wnf7.table(self.TABLE).insert(payload).execute()
        rows = list(response.data or [])
        if len(rows) != 1:
            raise WNF7ContractError("WNF-7 append did not return exactly one record")
        record = rows[0]
        if record.get("automated_state", result.automated_state.value) != result.automated_state.value:
            raise WNF7ContractError("database and runtime automated states disagree")
        if record.get("decision_eligibility", result.decision_eligibility.value) != result.decision_eligibility.value:
            raise WNF7ContractError("database and runtime eligibility disagree")
        return record
