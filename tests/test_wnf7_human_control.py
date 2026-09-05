from __future__ import annotations

import json
from pathlib import Path
import unittest

from setc.wnf7 import (
    AdjudicationStatus,
    EvidenceValidationStatus,
    ReviewerMobilizationStatus,
    WNF7ContractError,
    parse_adjudication_decision,
    parse_evidence_validation,
    parse_reviewer_appointment,
)


ROOT = Path(__file__).resolve().parents[1]
REVIEWER_ID = "00000000-0000-4000-8000-000000000001"
APPOINTER_ID = "00000000-0000-4000-8000-000000000002"


def appointment_payload() -> dict:
    return {
        "pilot_code": "PILOT-7D-001",
        "reviewer_role_code": "SETC_OWNER",
        "reviewer_subject_id": REVIEWER_ID,
        "reviewer_display_ref": "controlled://identity/reviewer/001",
        "appointment_evidence_ref": "controlled://SRC-013/appointment/SETC_OWNER",
        "appointed_by_subject_id": APPOINTER_ID,
        "conflict_status": "PENDING",
        "mobilization_status": "NOMINATED",
        "effective_at": "2026-09-04T22:00:00Z",
        "metadata": {"setup_mode": False},
    }


def validation_payload() -> dict:
    return {
        "pilot_code": "PILOT-7D-001",
        "scenario_code": "SCN-001",
        "candidate_evidence_ref": "controlled://SRC-011/scenario/SCN-001",
        "validation_evidence_ref": "controlled://SRC-013/validation/SCN-001",
        "source_system": "HUMAN_REVIEW",
        "content_sha256": "a" * 64,
        "freshness_status": "CURRENT",
        "validation_status": "VALIDATED",
        "observed_at": "2026-09-04T16:11:22Z",
        "validated_at": "2026-09-04T22:10:00Z",
        "validated_by": REVIEWER_ID,
        "validated_by_role_code": "SETC_OWNER",
        "rationale_summary": "Authority and rule references were reviewed against the controlled source.",
        "metadata": {"classification": "CONTROLLED_NON_PRODUCTION"},
    }


def decision_payload() -> dict:
    return {
        "pilot_code": "PILOT-7D-001",
        "scenario_code": "SCN-001",
        "reviewer_subject_id": REVIEWER_ID,
        "reviewer_role_code": "SETC_OWNER",
        "disposition": "CONFIRM",
        "decision_status": "COMPLETE",
        "rationale_summary": "The evidence supports the automated advisory posture.",
        "attestation_ref": "controlled://SRC-013/attestation/SCN-001",
        "decided_at": "2026-09-04T22:20:00Z",
        "evidence_refs": ["controlled://SRC-013/validation/SCN-001"],
        "automated_result_ref": "controlled://SRC-011/scenario/SCN-001",
        "metadata": {"classification": "CONTROLLED_NON_PRODUCTION"},
    }


class WNF7HumanControlTests(unittest.TestCase):
    def test_manifest_records_setup_mode_without_human_approval(self):
        manifest = json.loads(
            (ROOT / "docs/wnf7/pilot-evidence-mobilization-manifest.json").read_text(
                encoding="utf-8"
            )
        )
        control = manifest["human_control_status"]
        self.assertEqual(control["system_mode"], "SETUP")
        self.assertEqual(control["human_designer_status"], "SYSTEM_DESIGNER_NOT_APPROVER")
        self.assertEqual(control["reviewer_assignment_slots_initialized"], 6)
        self.assertEqual(control["nominated_reviewer_roles"], 5)
        self.assertEqual(control["unassigned_reviewer_roles"], 1)
        self.assertEqual(control["accepted_reviewer_roles"], 0)
        self.assertEqual(control["validated_evidence_packets"], 0)
        self.assertEqual(control["completed_decisions"], 0)
        self.assertFalse(control["production_authorized"])

    def test_governance_nomination_manifest_is_opaque_and_non_authorizing(self):
        path = ROOT / "docs/wnf7/governance-nomination-manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        serialized = json.dumps(manifest).lower()
        self.assertEqual(len(manifest["primary_role_nominations"]), 5)
        self.assertEqual(
            manifest["knowledge_governor_designation"]["appointment_status"],
            "AWAITING_INDEPENDENT_BOARD_CONFIRMATION",
        )
        self.assertEqual(
            manifest["alternate_reviewer"]["status"],
            "ALTERNATE_NOT_ASSIGNED_TO_PRIMARY_SLOT",
        )
        self.assertNotIn("@sourceenergyglobal.com", serialized)
        for name in ("peter", "steve", "dahlia", "olivia", "octavia", "justin"):
            self.assertNotIn(name, serialized)
        self.assertFalse(manifest["summary"]["production_authorized"])

    def test_nomination_packet_is_typed_but_does_not_accept_reviewer(self):
        packet = parse_reviewer_appointment(appointment_payload())
        self.assertEqual(packet.mobilization_status, ReviewerMobilizationStatus.NOMINATED)
        self.assertIsNone(packet.accepted_at)
        values = packet.to_assignment_values()
        self.assertFalse(values["metadata"]["production_authorized"])
        self.assertEqual(values["metadata"]["authority_posture"], "DOES_NOT_CONFER_AUTHORITY")

    def test_reviewer_cannot_self_appoint_or_bypass_acceptance_controls(self):
        payload = appointment_payload()
        payload["appointed_by_subject_id"] = REVIEWER_ID
        with self.assertRaisesRegex(WNF7ContractError, "cannot appoint themself"):
            parse_reviewer_appointment(payload)

        payload = appointment_payload()
        payload["mobilization_status"] = "ACCEPTED"
        with self.assertRaisesRegex(WNF7ContractError, "no-conflict"):
            parse_reviewer_appointment(payload)

        payload["conflict_status"] = "NO_CONFLICT_DECLARED"
        with self.assertRaisesRegex(WNF7ContractError, "accepted_at"):
            parse_reviewer_appointment(payload)

    def test_conflict_or_recusal_forces_hold(self):
        for conflict in ("CONFLICT_DECLARED", "RECUSED"):
            with self.subTest(conflict=conflict):
                payload = appointment_payload()
                payload["conflict_status"] = conflict
                payload["mobilization_status"] = "ASSIGNED"
                with self.assertRaisesRegex(WNF7ContractError, "requires HOLD"):
                    parse_reviewer_appointment(payload)

    def test_evidence_validation_requires_new_current_governed_record(self):
        packet = parse_evidence_validation(validation_payload())
        self.assertEqual(packet.validation_status, EvidenceValidationStatus.VALIDATED)
        values = packet.to_evidence_values("00000000-0000-4000-8000-000000000003")
        self.assertNotEqual(
            values["evidence_ref"], values["metadata"]["candidate_evidence_ref"]
        )
        self.assertFalse(values["metadata"]["production_authorized"])

        payload = validation_payload()
        payload["freshness_status"] = "STALE"
        with self.assertRaisesRegex(WNF7ContractError, "current or not applicable"):
            parse_evidence_validation(payload)

        payload = validation_payload()
        payload["validation_evidence_ref"] = payload["candidate_evidence_ref"]
        with self.assertRaisesRegex(WNF7ContractError, "new governed reference"):
            parse_evidence_validation(payload)

    def test_completed_adjudication_requires_attestation_and_nonexecuting_context(self):
        packet = parse_adjudication_decision(decision_payload())
        self.assertEqual(packet.decision_status, AdjudicationStatus.COMPLETE)
        values = packet.to_decision_values()
        self.assertIsNone(values.get("execution_command"))
        self.assertFalse(values["metadata"]["production_authorized"])

        payload = decision_payload()
        del payload["attestation_ref"]
        with self.assertRaisesRegex(WNF7ContractError, "requires an attestation"):
            parse_adjudication_decision(payload)

    def test_human_control_inputs_reject_production_execution_and_secrets(self):
        for factory, parser in (
            (appointment_payload, parse_reviewer_appointment),
            (validation_payload, parse_evidence_validation),
            (decision_payload, parse_adjudication_decision),
        ):
            with self.subTest(parser=parser.__name__, field="production_authorized"):
                payload = factory()
                payload["production_authorized"] = True
                with self.assertRaisesRegex(WNF7ContractError, "prohibited fields"):
                    parser(payload)
            with self.subTest(parser=parser.__name__, field="execution_command"):
                payload = factory()
                payload["execution_command"] = {"action": "execute"}
                with self.assertRaisesRegex(WNF7ContractError, "prohibited fields"):
                    parser(payload)
            with self.subTest(parser=parser.__name__, field="secret"):
                payload = factory()
                payload["metadata"] = {"api_key": "not-allowed"}
                with self.assertRaisesRegex(WNF7ContractError, "secret-bearing"):
                    parser(payload)

    def test_human_control_schemas_are_strict_and_cover_six_roles(self):
        roles = {
            "QA_LEAD",
            "TECH_AUTHORITY",
            "SETC_OWNER",
            "SOURCECUBE_OWNER",
            "PILOT_OWNER",
            "KNOWLEDGE_GOVERNOR",
        }
        for filename in (
            "reviewer-appointment-submission.schema.json",
            "evidence-validation-submission.schema.json",
            "adjudication-decision-submission.schema.json",
        ):
            with self.subTest(filename=filename):
                schema = json.loads((ROOT / "docs/wnf7" / filename).read_text(encoding="utf-8"))
                self.assertFalse(schema["additionalProperties"])
                self.assertEqual(set(schema["$defs"]["reviewerRole"]["enum"]), roles)
                self.assertNotIn("execution_command", schema["properties"])
                self.assertNotIn("production_authorized", schema["properties"])

    def test_setup_migration_cannot_advance_release_or_production(self):
        migration = (
            ROOT / "supabase/migrations/20260904221529_wnf7_human_control_setup.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION", migration)
        self.assertIn("with(security_invoker=true)", migration)
        self.assertNotIn("update wnf7.release_gates", migration.lower())
        self.assertNotIn("production_authorized=true", migration.lower())


if __name__ == "__main__":
    unittest.main()
