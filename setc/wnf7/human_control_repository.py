"""Trusted Supabase persistence for WNF-7 human-control submissions.

This server-only adapter exposes one controlled mutable surface (reviewer
assignment lifecycle) and two append-only surfaces (evidence and decisions).
It intentionally has no release-gate, delete, execution, or production method.
"""

from __future__ import annotations

from typing import Any, Mapping

from .models import WNF7ContractError
from .repository import SupabaseLikeClient


class SupabaseWNF7HumanControlRepository:
    """Allow-listed human-control persistence in the private ``wnf7`` schema."""

    ASSIGNMENTS = "reviewer_assignments"
    SCENARIOS = "pilot_scenarios"
    EVIDENCE = "evidence_items"
    DECISIONS = "adjudication_decisions"

    def __init__(self, client: SupabaseLikeClient) -> None:
        self._wnf7 = client.schema("wnf7")

    @staticmethod
    def _exactly_one(data: Any, message: str) -> Mapping[str, Any]:
        rows = list(data or [])
        if len(rows) != 1:
            raise WNF7ContractError(message)
        return rows[0]

    def find_assignment(
        self,
        pilot_code: str,
        reviewer_role_code: str,
    ) -> Mapping[str, Any]:
        response = (
            self._wnf7.table(self.ASSIGNMENTS)
            .select("*")
            .eq("pilot_code", pilot_code)
            .eq("reviewer_role_code", reviewer_role_code)
            .execute()
        )
        return self._exactly_one(
            response.data,
            "reviewer assignment lookup did not return exactly one slot",
        )

    def update_assignment(
        self,
        pilot_code: str,
        reviewer_role_code: str,
        expected_assignment_id: str,
        expected_mobilization_status: str,
        values: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        if values.get("pilot_code") != pilot_code:
            raise WNF7ContractError("reviewer assignment pilot identity changed")
        if values.get("reviewer_role_code") != reviewer_role_code:
            raise WNF7ContractError("reviewer assignment role identity changed")
        payload = dict(values)
        payload.pop("pilot_code")
        payload.pop("reviewer_role_code")
        response = (
            self._wnf7.table(self.ASSIGNMENTS)
            .update(payload)
            .eq("pilot_code", pilot_code)
            .eq("reviewer_role_code", reviewer_role_code)
            .eq("assignment_id", expected_assignment_id)
            .eq("mobilization_status", expected_mobilization_status)
            .execute()
        )
        return self._exactly_one(
            response.data,
            "reviewer assignment changed concurrently or update did not affect exactly one slot",
        )

    def find_scenario(
        self,
        pilot_code: str,
        scenario_code: str,
    ) -> Mapping[str, Any]:
        response = (
            self._wnf7.table(self.SCENARIOS)
            .select("*")
            .eq("pilot_code", pilot_code)
            .eq("scenario_code", scenario_code)
            .eq("active", True)
            .execute()
        )
        return self._exactly_one(
            response.data,
            "active pilot scenario lookup did not return exactly one record",
        )

    def find_candidate(
        self,
        scenario_code: str,
        candidate_evidence_ref: str,
    ) -> Mapping[str, Any]:
        response = (
            self._wnf7.table(self.EVIDENCE)
            .select("*")
            .eq("scenario_code", scenario_code)
            .eq("evidence_ref", candidate_evidence_ref)
            .eq("validation_status", "PENDING")
            .execute()
        )
        candidate = self._exactly_one(
            response.data,
            "pending candidate evidence lookup did not return exactly one record",
        )
        if candidate.get("metadata", {}).get("evidence_stage") != "CANDIDATE":
            raise WNF7ContractError("evidence record is not a governed candidate")
        return candidate

    def find_validated_evidence(
        self,
        scenario_code: str,
        evidence_ref: str,
        reviewer_subject_id: str,
        reviewer_role_code: str,
    ) -> Mapping[str, Any]:
        response = (
            self._wnf7.table(self.EVIDENCE)
            .select("*")
            .eq("scenario_code", scenario_code)
            .eq("evidence_ref", evidence_ref)
            .eq("validation_status", "VALIDATED")
            .eq("validated_by", reviewer_subject_id)
            .eq("validated_by_role_code", reviewer_role_code)
            .execute()
        )
        return self._exactly_one(
            response.data,
            "validated evidence reference did not resolve to exactly one governed record",
        )

    def append_evidence(self, values: Mapping[str, Any]) -> Mapping[str, Any]:
        response = self._wnf7.table(self.EVIDENCE).insert(values).execute()
        return self._exactly_one(
            response.data,
            "evidence append did not return exactly one record",
        )

    def append_decision(self, values: Mapping[str, Any]) -> Mapping[str, Any]:
        response = self._wnf7.table(self.DECISIONS).insert(values).execute()
        return self._exactly_one(
            response.data,
            "adjudication append did not return exactly one record",
        )
