from __future__ import annotations

from copy import deepcopy
from types import SimpleNamespace
import unittest
from uuid import uuid4

from setc.wnf7 import (
    SupabaseWNF7HumanControlRepository,
    WNF7ContractError,
    WNF7HumanControlService,
    parse_reviewer_appointment,
)


PILOT = "PILOT-7D-001"
ROLE = "SETC_OWNER"
REVIEWER_ID = "00000000-0000-4000-8000-000000000001"
SECOND_REVIEWER_ID = "00000000-0000-4000-8000-000000000004"
APPOINTER_ID = "00000000-0000-4000-8000-000000000002"
CANDIDATE_ID = "00000000-0000-4000-8000-000000000003"
CANDIDATE_REF = "controlled://SRC-011/scenario/SCN-001"
VALIDATION_REF = "controlled://SRC-013/validation/SCN-001"


class FakeQuery:
    def __init__(self, database: dict[str, list[dict]], table: str) -> None:
        self.database = database
        self.table = table
        self.operation = "select"
        self.filters: list[tuple[str, object]] = []
        self.payload: dict | None = None

    def select(self, columns: str = "*") -> "FakeQuery":
        self.operation = "select"
        return self

    def eq(self, column: str, value: object) -> "FakeQuery":
        self.filters.append((column, value))
        return self

    def update(self, payload: dict) -> "FakeQuery":
        self.operation = "update"
        self.payload = deepcopy(payload)
        return self

    def insert(self, payload: dict) -> "FakeQuery":
        self.operation = "insert"
        self.payload = deepcopy(payload)
        return self

    def _matches(self, row: dict) -> bool:
        return all(row.get(column) == value for column, value in self.filters)

    def execute(self) -> SimpleNamespace:
        rows = self.database[self.table]
        if self.operation == "select":
            return SimpleNamespace(data=[deepcopy(row) for row in rows if self._matches(row)])
        if self.operation == "update":
            updated = []
            for row in rows:
                if self._matches(row):
                    row.update(deepcopy(self.payload or {}))
                    updated.append(deepcopy(row))
            return SimpleNamespace(data=updated)
        record = deepcopy(self.payload or {})
        if self.table == "evidence_items":
            record.setdefault("evidence_id", str(uuid4()))
        elif self.table == "adjudication_decisions":
            record.setdefault("decision_id", str(uuid4()))
        rows.append(record)
        return SimpleNamespace(data=[deepcopy(record)])


class FakeSchema:
    def __init__(self, database: dict[str, list[dict]]) -> None:
        self.database = database

    def table(self, name: str) -> FakeQuery:
        return FakeQuery(self.database, name)


class FakeSupabase:
    def __init__(self, database: dict[str, list[dict]]) -> None:
        self.database = database
        self.schemas: list[str] = []

    def schema(self, name: str) -> FakeSchema:
        self.schemas.append(name)
        return FakeSchema(self.database)


def database(*, assignment_status: str = "UNASSIGNED") -> dict[str, list[dict]]:
    accepted = assignment_status == "ACCEPTED"
    return {
        "reviewer_assignments": [
            {
                "assignment_id": str(uuid4()),
                "pilot_code": PILOT,
                "reviewer_role_code": ROLE,
                "reviewer_subject_id": REVIEWER_ID if assignment_status != "UNASSIGNED" else None,
                "reviewer_display_ref": (
                    "controlled://identity/reviewer/001"
                    if assignment_status != "UNASSIGNED"
                    else None
                ),
                "appointment_evidence_ref": (
                    "controlled://SRC-013/appointment/SETC_OWNER"
                    if assignment_status != "UNASSIGNED"
                    else None
                ),
                "conflict_status": "NO_CONFLICT_DECLARED" if accepted else "PENDING",
                "mobilization_status": assignment_status,
                "accepted_at": "2026-09-04T22:05:00Z" if accepted else None,
                "metadata": {},
            }
        ],
        "pilot_scenarios": [
            {
                "scenario_code": "SCN-001",
                "pilot_code": PILOT,
                "reviewer_role_code": ROLE,
                "active": True,
            }
        ],
        "evidence_items": [
            {
                "evidence_id": CANDIDATE_ID,
                "scenario_code": "SCN-001",
                "evidence_ref": CANDIDATE_REF,
                "validation_status": "PENDING",
                "metadata": {"evidence_stage": "CANDIDATE"},
            }
        ],
        "adjudication_decisions": [],
    }


def appointment_payload(
    *, status: str = "NOMINATED", reviewer_id: str = REVIEWER_ID
) -> dict:
    payload = {
        "pilot_code": PILOT,
        "reviewer_role_code": ROLE,
        "reviewer_subject_id": reviewer_id,
        "reviewer_display_ref": "controlled://identity/reviewer/001",
        "appointment_evidence_ref": "controlled://SRC-013/appointment/SETC_OWNER",
        "appointed_by_subject_id": APPOINTER_ID,
        "conflict_status": "PENDING",
        "mobilization_status": status,
        "effective_at": "2026-09-04T22:00:00Z",
        "metadata": {"classification": "CONTROLLED_NON_PRODUCTION"},
    }
    if status == "ACCEPTED":
        payload["conflict_status"] = "NO_CONFLICT_DECLARED"
        payload["accepted_at"] = "2026-09-04T22:05:00Z"
    return payload


def validation_payload() -> dict:
    return {
        "pilot_code": PILOT,
        "scenario_code": "SCN-001",
        "candidate_evidence_ref": CANDIDATE_REF,
        "validation_evidence_ref": VALIDATION_REF,
        "source_system": "HUMAN_REVIEW",
        "content_sha256": "a" * 64,
        "freshness_status": "CURRENT",
        "validation_status": "VALIDATED",
        "observed_at": "2026-09-04T16:11:22Z",
        "validated_at": "2026-09-04T22:10:00Z",
        "validated_by": REVIEWER_ID,
        "validated_by_role_code": ROLE,
        "rationale_summary": "Controlled evidence reviewed against the governed source.",
        "metadata": {"classification": "CONTROLLED_NON_PRODUCTION"},
    }


def decision_payload() -> dict:
    return {
        "pilot_code": PILOT,
        "scenario_code": "SCN-001",
        "reviewer_subject_id": REVIEWER_ID,
        "reviewer_role_code": ROLE,
        "disposition": "CONFIRM",
        "decision_status": "COMPLETE",
        "rationale_summary": "Validated evidence supports the advisory posture.",
        "attestation_ref": "controlled://SRC-013/attestation/SCN-001",
        "decided_at": "2026-09-04T22:20:00Z",
        "evidence_refs": [VALIDATION_REF],
        "automated_result_ref": CANDIDATE_REF,
        "metadata": {"classification": "CONTROLLED_NON_PRODUCTION"},
    }


def service(data: dict[str, list[dict]]) -> WNF7HumanControlService:
    repository = SupabaseWNF7HumanControlRepository(FakeSupabase(data))
    return WNF7HumanControlService(repository)


class WNF7HumanControlServiceTests(unittest.TestCase):
    def test_nomination_updates_exact_slot_without_authority(self):
        data = database()
        receipt = service(data).submit_reviewer_appointment(appointment_payload())
        self.assertEqual(data["reviewer_assignments"][0]["mobilization_status"], "NOMINATED")
        self.assertEqual(receipt.action, "REVIEWER_LIFECYCLE_RECORDED")
        self.assertFalse(receipt.may_execute)
        self.assertFalse(receipt.production_authorized)
        self.assertEqual(receipt.authority_posture, "DOES_NOT_CONFER_AUTHORITY")

    def test_direct_acceptance_and_in_place_subject_replacement_are_blocked(self):
        with self.assertRaisesRegex(WNF7ContractError, "not permitted"):
            service(database()).submit_reviewer_appointment(
                appointment_payload(status="ACCEPTED")
            )

        data = database(assignment_status="NOMINATED")
        with self.assertRaisesRegex(WNF7ContractError, "replacement requires"):
            service(data).submit_reviewer_appointment(
                appointment_payload(status="ASSIGNED", reviewer_id=SECOND_REVIEWER_ID)
            )

    def test_evidence_validation_requires_accepted_assignment_and_appends_lineage(self):
        with self.assertRaisesRegex(WNF7ContractError, "accepted reviewer"):
            service(database()).submit_evidence_validation(validation_payload())

        data = database(assignment_status="ACCEPTED")
        receipt = service(data).submit_evidence_validation(validation_payload())
        record = receipt.persisted_record
        self.assertEqual(record["candidate_evidence_id"], CANDIDATE_ID)
        self.assertEqual(record["evidence_ref"], VALIDATION_REF)
        self.assertEqual(record["validation_status"], "VALIDATED")
        self.assertEqual(len(data["evidence_items"]), 2)
        self.assertFalse(receipt.production_authorized)

    def test_candidate_lookup_rejects_missing_or_non_candidate_records(self):
        data = database(assignment_status="ACCEPTED")
        data["evidence_items"][0]["metadata"] = {"evidence_stage": "OTHER"}
        with self.assertRaisesRegex(WNF7ContractError, "not a governed candidate"):
            service(data).submit_evidence_validation(validation_payload())

        data = database(assignment_status="ACCEPTED")
        data["evidence_items"].clear()
        with self.assertRaisesRegex(WNF7ContractError, "exactly one"):
            service(data).submit_evidence_validation(validation_payload())

    def test_adjudication_requires_governed_candidate_and_each_evidence_reference(self):
        data = database(assignment_status="ACCEPTED")
        human_service = service(data)
        human_service.submit_evidence_validation(validation_payload())
        receipt = human_service.submit_adjudication(decision_payload())
        self.assertEqual(receipt.action, "ADJUDICATION_APPENDED")
        self.assertEqual(len(data["adjudication_decisions"]), 1)
        self.assertFalse(receipt.may_execute)

        payload = decision_payload()
        payload["evidence_refs"] = ["controlled://SRC-013/validation/missing"]
        with self.assertRaisesRegex(WNF7ContractError, "exactly one"):
            human_service.submit_adjudication(payload)

    def test_repository_and_service_expose_no_release_execution_or_delete_api(self):
        repository = SupabaseWNF7HumanControlRepository(FakeSupabase(database()))
        human_service = WNF7HumanControlService(repository)
        prohibited = ("release", "authorize", "execute", "delete", "production")
        for subject in (repository, human_service):
            public_names = [name for name in dir(subject) if not name.startswith("_")]
            for token in prohibited:
                self.assertFalse(
                    any(token in name.lower() for name in public_names),
                    f"{type(subject).__name__} exposes prohibited token {token}",
                )

    def test_repository_requires_exactly_one_assignment_slot(self):
        data = database()
        data["reviewer_assignments"].append(deepcopy(data["reviewer_assignments"][0]))
        repository = SupabaseWNF7HumanControlRepository(FakeSupabase(data))
        with self.assertRaisesRegex(WNF7ContractError, "exactly one slot"):
            repository.find_assignment(PILOT, ROLE)

    def test_repository_update_fails_closed_on_stale_lifecycle_state(self):
        data = database()
        repository = SupabaseWNF7HumanControlRepository(FakeSupabase(data))
        values = appointment_payload()
        assignment_values = parse_reviewer_appointment(values).to_assignment_values()
        with self.assertRaisesRegex(WNF7ContractError, "changed concurrently"):
            repository.update_assignment(
                PILOT,
                ROLE,
                data["reviewer_assignments"][0]["assignment_id"],
                "NOMINATED",
                assignment_values,
            )


if __name__ == "__main__":
    unittest.main()
