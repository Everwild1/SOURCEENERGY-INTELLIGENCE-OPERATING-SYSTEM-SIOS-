from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import unittest

from src.sourceenergy_one.heartbeat_assertion import VerificationContext
from src.sourceenergy_one.signed_heartbeat_assertion import (
    ProviderAssertionRejected, SignedProviderEnvelope, canonical_payload, verify_signed_envelope,
)


class SignedProviderTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 8, 30, 12, 0, tzinfo=timezone.utc)
        self.payload = {
            "subject_id":"s1","challenge_id":"c1","verification_status":"verified","liveness_status":"passed",
            "assurance_level":"institutional","assertion_digest":"d1","issued_at":(self.now-timedelta(seconds=30)).isoformat(),
            "expires_at":(self.now+timedelta(minutes=3)).isoformat(),"sensor_attestation_ref":"sensor-attest-1"
        }
        self.context = VerificationContext("s1","c1","elevated",True)
        self.trust = {"heartbeat-staging": {"key-1"}}

    def envelope(self, issuer="heartbeat-staging", key_id="key-1", algorithm="ES256"):
        return SignedProviderEnvelope(issuer,key_id,algorithm,self.payload,"sig")

    @staticmethod
    def accept(*_args): return True
    @staticmethod
    def reject(*_args): return False

    def test_accepts_trusted_valid_signed_assertion(self):
        a = verify_signed_envelope(self.envelope(), trusted_issuers=self.trust, signature_verifier=self.accept, context=self.context, now=self.now)
        self.assertEqual(a.subject_id,"s1")

    def test_rejects_unknown_issuer(self):
        with self.assertRaises(ProviderAssertionRejected):
            verify_signed_envelope(self.envelope(issuer="evil"), trusted_issuers=self.trust, signature_verifier=self.accept, context=self.context, now=self.now)

    def test_rejects_unknown_key(self):
        with self.assertRaises(ProviderAssertionRejected):
            verify_signed_envelope(self.envelope(key_id="old"), trusted_issuers=self.trust, signature_verifier=self.accept, context=self.context, now=self.now)

    def test_rejects_invalid_signature(self):
        with self.assertRaises(ProviderAssertionRejected):
            verify_signed_envelope(self.envelope(), trusted_issuers=self.trust, signature_verifier=self.reject, context=self.context, now=self.now)

    def test_rejects_hmac_algorithm(self):
        with self.assertRaises(ProviderAssertionRejected):
            verify_signed_envelope(self.envelope(algorithm="HS256"), trusted_issuers=self.trust, signature_verifier=self.accept, context=self.context, now=self.now)

    def test_requires_sensor_attestation(self):
        self.payload["sensor_attestation_ref"]=""
        with self.assertRaises(ProviderAssertionRejected):
            verify_signed_envelope(self.envelope(), trusted_issuers=self.trust, signature_verifier=self.accept, context=self.context, now=self.now)


if __name__ == "__main__": unittest.main()
