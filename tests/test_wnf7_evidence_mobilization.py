from __future__ import annotations

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs/wnf7/pilot-evidence-mobilization-manifest.json"
MIGRATION_PATH = ROOT / "supabase/migrations/20260904204433_wnf7_evidence_mobilization.sql"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


EXPECTED_SCENARIOS = {
    "SCN-001": (("FEAR",), "PASS", "ELIGIBLE_FOR_HUMAN_DECISION", "SETC_OWNER"),
    "SCN-002": (("FEAR",), "BLOCKED", "NOT_ELIGIBLE", "SETC_OWNER"),
    "SCN-003": (("FEAR",), "BLOCKED", "NOT_ELIGIBLE", "SETC_OWNER"),
    "SCN-004": (("PRESENCE",), "REVIEW", "SIMULATION_ONLY", "TECH_AUTHORITY"),
    "SCN-005": (("KNOWLEDGE",), "REVIEW", "SIMULATION_ONLY", "QA_LEAD"),
    "SCN-006": (("KNOWLEDGE",), "REVIEW", "SIMULATION_ONLY", "QA_LEAD"),
    "SCN-007": (("KNOWLEDGE",), "BLOCKED", "NOT_ELIGIBLE", "QA_LEAD"),
    "SCN-008": (("WISDOM",), "BLOCKED", "NOT_ELIGIBLE", "PILOT_OWNER"),
    "SCN-009": (("UNDERSTANDING",), "REVIEW", "SIMULATION_ONLY", "QA_LEAD"),
    "SCN-010": (("UNDERSTANDING",), "BLOCKED", "NOT_ELIGIBLE", "QA_LEAD"),
    "SCN-011": (("COUNSEL",), "BLOCKED", "NOT_ELIGIBLE", "KNOWLEDGE_GOVERNOR"),
    "SCN-012": (("COUNSEL",), "BLOCKED", "NOT_ELIGIBLE", "KNOWLEDGE_GOVERNOR"),
    "SCN-013": (("MIGHT_POWER",), "BLOCKED", "NOT_ELIGIBLE", "SOURCECUBE_OWNER"),
    "SCN-014": (("MIGHT_POWER",), "REVIEW", "SIMULATION_ONLY", "SOURCECUBE_OWNER"),
    "SCN-015": (
        (
            "FEAR",
            "PRESENCE",
            "WISDOM",
            "KNOWLEDGE",
            "UNDERSTANDING",
            "COUNSEL",
            "MIGHT_POWER",
        ),
        "BLOCKED",
        "NOT_ELIGIBLE",
        "KNOWLEDGE_GOVERNOR",
    ),
}


class WNF7EvidenceMobilizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.migration = MIGRATION_PATH.read_text(encoding="utf-8")

    def test_manifest_preserves_non_production_human_control(self):
        control = self.manifest["human_control_status"]
        self.assertEqual(control["accepted_reviewer_roles"], 0)
        self.assertEqual(control["validated_evidence_packets"], 0)
        self.assertEqual(control["completed_decisions"], 0)
        self.assertEqual(control["gate_state"], "HOLD")
        self.assertEqual(control["derived_operational_readiness"], "HOLD_INCOMPLETE")
        self.assertEqual(
            control["evidence_mobilization_state"],
            "MOBILIZED_PENDING_HUMAN_VALIDATION",
        )
        self.assertFalse(control["production_authorized"])
        self.assertFalse(self.manifest["sources"]["technical_package"]["execution_allowed"])
        self.assertFalse(self.manifest["guardrails"]["execution_allowed"])

    def test_all_package_artifacts_match_sha256_manifest(self):
        integrity = self.manifest["integrity"]
        self.assertTrue(integrity["artifact_integrity_verified"])
        self.assertFalse(integrity["substantive_validation_complete"])
        self.assertRegex(integrity["manifest_sha256"], SHA256)
        artifacts = integrity["artifacts"]
        self.assertEqual(len(artifacts), 7)
        self.assertEqual(
            {item["name"] for item in artifacts},
            {
                "README.md",
                "charter-scenarios.json",
                "run-charter-portfolio.js",
                "charter-results.json",
                "charter-ledger.jsonl",
                "reviewer-adjudication-queue.json",
                "defect-register.json",
            },
        )
        for artifact in artifacts:
            self.assertRegex(artifact["sha256"], SHA256)
            self.assertTrue(artifact["matches_manifest"])

    def test_manifest_covers_exact_scenario_contract_as_pending_candidates(self):
        scenarios = self.manifest["scenarios"]
        self.assertEqual(len(scenarios), 15)
        self.assertEqual({item["scenario_code"] for item in scenarios}, set(EXPECTED_SCENARIOS))
        for item in scenarios:
            expected = EXPECTED_SCENARIOS[item["scenario_code"]]
            self.assertEqual(tuple(item["dimensions"]), expected[0])
            self.assertEqual(item["expected_automated_state"], expected[1])
            self.assertEqual(item["decision_eligibility"], expected[2])
            self.assertEqual(item["reviewer_role_code"], expected[3])
            self.assertTrue(item["required_evidence"].strip())
            self.assertEqual(
                item["candidate_evidence_ref"],
                f"controlled://SRC-011/scenario/{item['scenario_code']}",
            )
            self.assertEqual(item["freshness_status"], "PENDING")
            self.assertEqual(item["validation_status"], "PENDING")

    def test_manifest_covers_all_eight_ecosystem_components(self):
        self.assertEqual(
            set(self.manifest["covered_components"]),
            {
                "SETC",
                "SOURCECUBE",
                "CODEX_VERITAS",
                "SOURCEONE",
                "SIOS",
                "SIDEKICK_OEL",
                "SOURCECOIN",
                "SOURCEBLOCK",
            },
        )

    def test_manifest_and_migration_do_not_embed_private_drive_locations(self):
        serialized = json.dumps(self.manifest, sort_keys=True).lower()
        migration = self.migration.lower()
        for prohibited in ("drive.google.com", "docs.google.com", "https://", "http://"):
            self.assertNotIn(prohibited, serialized)
            self.assertNotIn(prohibited, migration)
        for item in self.manifest["scenarios"]:
            self.assertTrue(item["candidate_evidence_ref"].startswith("controlled://SRC-011/"))

    def test_migration_is_append_only_pending_and_does_not_advance_authority(self):
        self.assertIn("evidence_items_scenario_ref_uidx", self.migration)
        self.assertIn("with(security_invoker=true)", self.migration)
        self.assertIn("'PENDING',\n  'PENDING'", self.migration)
        self.assertIn("MOBILIZED_PENDING_HUMAN_VALIDATION", self.migration)
        self.assertNotIn("update wnf7.release_gates", self.migration.lower())
        self.assertNotIn("production_authorized=true", self.migration.lower())


if __name__ == "__main__":
    unittest.main()
