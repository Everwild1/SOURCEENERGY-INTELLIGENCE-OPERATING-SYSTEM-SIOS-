import unittest

from src.sourceenergy_one.genesis_experience import GenesisExperienceContext
from src.sourceenergy_one.genesis_package import (
    GenesisBoundaryError,
    GenesisCandidate,
    canonical_payload,
    provenance_hash,
    validate_candidate,
)


def ready_context() -> GenesisExperienceContext:
    return GenesisExperienceContext(
        identity_verified=True,
        consent_recorded=True,
        purpose_profile_complete=True,
        codex24_candidate_complete=True,
        human_approved=True,
    )


def valid_candidate() -> GenesisCandidate:
    return GenesisCandidate(
        subject_id="subject-001",
        subject_type="person",
        schema_version="1.0",
        purpose_profile_id="purpose-001",
        purpose_source_hash="purpose-hash",
        approved_mvp_artifact_id="mvp-001",
        approved_mvp_hash="mvp-hash",
        impact_report_id="impact-001",
        impact_report_hash="impact-hash",
        impact_horizons={
            "present": "baseline",
            "1": "year-1",
            "5": "year-5",
            "10": "year-10",
            "25": "year-25",
            "50": "year-50",
            "100": "year-100",
        },
        consent_ids=("consent-001",),
        codex24_package_version="codex24-v1",
        jurisdiction="US-VA",
        authorizing_actor_id="human-approver-001",
        authorization_attestation="attestation-001",
    )


class GenesisPackageTests(unittest.TestCase):
    def test_human_approval_is_mandatory(self):
        context = GenesisExperienceContext(
            identity_verified=True,
            consent_recorded=True,
            purpose_profile_complete=True,
            codex24_candidate_complete=True,
            human_approved=False,
        )
        with self.assertRaises(GenesisBoundaryError):
            validate_candidate(context, valid_candidate())

    def test_all_impact_horizons_are_required(self):
        candidate = valid_candidate()
        candidate = GenesisCandidate(**{**candidate.__dict__, "impact_horizons": {"present": "baseline", "1": "year-1"}})
        with self.assertRaises(GenesisBoundaryError):
            validate_candidate(ready_context(), candidate)

    def test_consent_reference_is_required(self):
        candidate = valid_candidate()
        candidate = GenesisCandidate(**{**candidate.__dict__, "consent_ids": ()})
        with self.assertRaises(GenesisBoundaryError):
            validate_candidate(ready_context(), candidate)

    def test_payload_excludes_raw_purpose_narrative(self):
        candidate = valid_candidate()
        validate_candidate(ready_context(), candidate)
        payload = canonical_payload(candidate)
        self.assertNotIn("purpose_narrative", payload)
        self.assertEqual(payload["purpose_source_hash"], "purpose-hash")

    def test_provenance_hash_is_deterministic(self):
        candidate = valid_candidate()
        validate_candidate(ready_context(), candidate)
        self.assertEqual(provenance_hash(candidate), provenance_hash(candidate))
        self.assertEqual(len(provenance_hash(candidate)), 64)


if __name__ == "__main__":
    unittest.main()
