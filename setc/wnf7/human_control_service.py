"""Application service for controlled WNF-7 human-stage persistence.

The service performs deterministic preflight checks before the private Supabase
schema applies its own constraints and triggers. It does not grant authority,
advance a release gate, issue a command, or authorize production.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, Protocol

from .human_control import parse_adjudication_decision, parse_evidence_validation
from .models import WNF7ContractError
from .review import parse_reviewer_appointment


class HumanControlRepository(Protocol):
    def find_assignment(self, pilot_code: str, reviewer_role_code: str) -> Mapping[str, Any]: ...
    def update_assignment(
        self,
        pilot_code: str,
        reviewer_role_code: str,
        expected_assignment_id: str,
        expected_mobilization_status: str,
        values: Mapping[str, Any],
    ) -> Mapping[str, Any]: ...
    def find_scenario(self, pilot_code: str, scenario_code: str) -> Mapping[str, Any]: ...
    def find_candidate(
        self, scenario_code: str, candidate_evidence_ref: str
    ) -> Mapping[str, Any]: ...
    def find_validated_evidence(
        self,
        scenario_code: str,
        evidence_ref: str,
        reviewer_subject_id: str,
        reviewer_role_code: str,
    ) -> Mapping[str, Any]: ...
    def append_evidence(self, values: Mapping[str, Any]) -> Mapping[str, Any]: ...
    def append_decision(self, values: Mapping[str, Any]) -> Mapping[str, Any]: ...


@dataclass(frozen=True, slots=True)
class HumanControlReceipt:
    action: str
    persisted_record: Mapping[str, Any]

    @property
    def may_execute(self) -> bool:
        return False

    @property
    def production_authorized(self) -> bool:
        return False

    @property
    def authority_posture(self) -> str:
        return "DOES_NOT_CONFER_AUTHORITY"


_TRANSITIONS = {
    "UNASSIGNED": frozenset({"NOMINATED", "HOLD"}),
    "NOMINATED": frozenset({"ASSIGNED", "HOLD"}),
    "ASSIGNED": frozenset({"ACCEPTED", "HOLD"}),
    "ACCEPTED": frozenset({"HOLD"}),
    "HOLD": frozenset({"NOMINATED"}),
}


class WNF7HumanControlService:
    """Trusted ingress for reviewer, evidence, and adjudication submissions."""

    def __init__(self, repository: HumanControlRepository) -> None:
        self._repository = repository

    @staticmethod
    def _require_transition(current: Mapping[str, Any], target: str) -> None:
        source = current.get("mobilization_status")
        if source not in _TRANSITIONS or target not in _TRANSITIONS[source]:
            raise WNF7ContractError(
                f"reviewer lifecycle transition {source!r} -> {target!r} is not permitted"
            )

    @staticmethod
    def _require_accepted_assignment(
        assignment: Mapping[str, Any],
        *,
        reviewer_subject_id: str,
    ) -> None:
        if assignment.get("mobilization_status") != "ACCEPTED":
            raise WNF7ContractError("human action requires an accepted reviewer assignment")
        if assignment.get("conflict_status") != "NO_CONFLICT_DECLARED":
            raise WNF7ContractError("human action requires a no-conflict reviewer")
        if assignment.get("reviewer_subject_id") != reviewer_subject_id:
            raise WNF7ContractError("human action reviewer does not match the accepted assignment")
        if not assignment.get("appointment_evidence_ref"):
            raise WNF7ContractError("human action requires governed appointment evidence")

    def submit_reviewer_appointment(
        self, payload: Mapping[str, Any]
    ) -> HumanControlReceipt:
        submission = parse_reviewer_appointment(payload)
        role = submission.reviewer_role_code.value
        current = self._repository.find_assignment(submission.pilot_code, role)
        target = submission.mobilization_status.value
        self._require_transition(current, target)
        assignment_id = current.get("assignment_id")
        current_status = current.get("mobilization_status")
        if not assignment_id or not current_status:
            raise WNF7ContractError("reviewer assignment is missing lifecycle identity")

        current_subject = current.get("reviewer_subject_id")
        new_subject = str(submission.reviewer_subject_id)
        if (
            current_subject
            and current_subject != new_subject
            and current.get("mobilization_status") != "HOLD"
        ):
            raise WNF7ContractError(
                "reviewer subject replacement requires the current slot to enter HOLD first"
            )

        record = self._repository.update_assignment(
            submission.pilot_code,
            role,
            str(assignment_id),
            str(current_status),
            submission.to_assignment_values(),
        )
        return HumanControlReceipt("REVIEWER_LIFECYCLE_RECORDED", record)

    def submit_evidence_validation(
        self, payload: Mapping[str, Any]
    ) -> HumanControlReceipt:
        submission = parse_evidence_validation(payload)
        role = submission.validated_by_role_code.value
        scenario = self._repository.find_scenario(
            submission.pilot_code,
            submission.scenario_code,
        )
        if scenario.get("reviewer_role_code") != role:
            raise WNF7ContractError("evidence reviewer role does not match the pilot scenario")
        assignment = self._repository.find_assignment(submission.pilot_code, role)
        self._require_accepted_assignment(
            assignment,
            reviewer_subject_id=str(submission.validated_by),
        )
        candidate = self._repository.find_candidate(
            submission.scenario_code,
            submission.candidate_evidence_ref,
        )
        candidate_id = candidate.get("evidence_id")
        if not candidate_id:
            raise WNF7ContractError("candidate evidence is missing its governed identifier")
        record = self._repository.append_evidence(
            submission.to_evidence_values(candidate_id)
        )
        return HumanControlReceipt("EVIDENCE_VALIDATION_APPENDED", record)

    def submit_adjudication(
        self, payload: Mapping[str, Any]
    ) -> HumanControlReceipt:
        submission = parse_adjudication_decision(payload)
        role = submission.reviewer_role_code.value
        scenario = self._repository.find_scenario(
            submission.pilot_code,
            submission.scenario_code,
        )
        if scenario.get("reviewer_role_code") != role:
            raise WNF7ContractError("adjudication reviewer role does not match the pilot scenario")
        assignment = self._repository.find_assignment(submission.pilot_code, role)
        reviewer_id = str(submission.reviewer_subject_id)
        self._require_accepted_assignment(assignment, reviewer_subject_id=reviewer_id)
        self._repository.find_candidate(
            submission.scenario_code,
            submission.automated_result_ref,
        )
        for evidence_ref in submission.evidence_refs:
            self._repository.find_validated_evidence(
                submission.scenario_code,
                evidence_ref,
                reviewer_id,
                role,
            )
        record = self._repository.append_decision(submission.to_decision_values())
        return HumanControlReceipt("ADJUDICATION_APPENDED", record)
