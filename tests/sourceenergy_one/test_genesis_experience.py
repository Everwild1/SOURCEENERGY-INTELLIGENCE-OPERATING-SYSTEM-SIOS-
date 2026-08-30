import unittest

from sourceenergy_one.genesis_experience import (
    GenesisExperienceContext,
    GenesisStage,
    can_create_genesis,
    resolve_stage,
)


class GenesisExperienceTests(unittest.TestCase):
    def test_progression_is_fail_closed(self):
        self.assertEqual(resolve_stage(GenesisExperienceContext()), GenesisStage.IDENTITY)
        self.assertEqual(resolve_stage(GenesisExperienceContext(identity_verified=True)), GenesisStage.CONSENT)
        self.assertEqual(resolve_stage(GenesisExperienceContext(identity_verified=True, consent_recorded=True)), GenesisStage.PURPOSE_DISCOVERY)
        self.assertEqual(resolve_stage(GenesisExperienceContext(identity_verified=True, consent_recorded=True, purpose_profile_complete=True)), GenesisStage.CODEX24_SYNTHESIS)

    def test_codex24_candidate_requires_human_review(self):
        context = GenesisExperienceContext(
            identity_verified=True,
            consent_recorded=True,
            purpose_profile_complete=True,
            codex24_candidate_complete=True,
            human_approved=False,
        )
        self.assertEqual(resolve_stage(context), GenesisStage.HUMAN_REVIEW)
        self.assertFalse(can_create_genesis(context))

    def test_only_human_approved_complete_context_is_genesis_ready(self):
        context = GenesisExperienceContext(
            identity_verified=True,
            consent_recorded=True,
            purpose_profile_complete=True,
            codex24_candidate_complete=True,
            human_approved=True,
        )
        self.assertEqual(resolve_stage(context), GenesisStage.GENESIS_READY)
        self.assertTrue(can_create_genesis(context))


if __name__ == "__main__":
    unittest.main()
