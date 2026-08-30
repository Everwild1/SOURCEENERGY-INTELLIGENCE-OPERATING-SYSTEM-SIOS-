from datetime import datetime, timedelta, timezone
from dataclasses import replace
import unittest

from src.sourceenergy_one.heartbeat_assertion import (
    AssertionRejected,
    HeartBeatAssertion,
    VerificationContext,
    verify_assertion,
)


class HeartBeatAssertionTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 8, 30, 12, 0, tzinfo=timezone.utc)
        self.assertion = HeartBeatAssertion(
            subject_id="subject-1",
            challenge_id="challenge-1",
            verification_status="verified",
            liveness_status="passed",
            assurance_level="institutional",
            assertion_digest="digest-1",
            issued_at=self.now - timedelta(minutes=1),
            expires_at=self.now + timedelta(minutes=4),
        )
        self.context = VerificationContext(
            expected_subject_id="subject-1",
            expected_challenge_id="challenge-1",
            minimum_assurance="elevated",
            require_liveness=True,
        )

    def test_accepts_fresh_matching_assertion(self):
        self.assertEqual(verify_assertion(self.assertion, self.context, now=self.now), self.assertion)

    def test_rejects_replay(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(self.assertion, self.context, now=self.now, consumed_digests=frozenset({"digest-1"}))

    def test_rejects_wrong_challenge(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, challenge_id="other"), self.context, now=self.now)

    def test_rejects_expired(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, expires_at=self.now), self.context, now=self.now)

    def test_rejects_revoked(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, revoked_at=self.now - timedelta(seconds=1)), self.context, now=self.now)

    def test_rejects_failed_liveness(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, liveness_status="failed"), self.context, now=self.now)

    def test_rejects_insufficient_assurance(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, assurance_level="standard"), self.context, now=self.now)

    def test_rejects_subject_mismatch(self):
        with self.assertRaises(AssertionRejected):
            verify_assertion(replace(self.assertion, subject_id="other"), self.context, now=self.now)


if __name__ == "__main__":
    unittest.main()
