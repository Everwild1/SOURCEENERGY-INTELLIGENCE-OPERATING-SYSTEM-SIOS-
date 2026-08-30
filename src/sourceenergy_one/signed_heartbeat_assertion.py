from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import hmac
import json
from typing import Callable, Mapping

from .heartbeat_assertion import HeartBeatAssertion, VerificationContext, verify_assertion


class ProviderAssertionRejected(ValueError):
    pass


@dataclass(frozen=True)
class SignedProviderEnvelope:
    issuer: str
    key_id: str
    algorithm: str
    payload: Mapping[str, str]
    signature: str


def canonical_payload(envelope: SignedProviderEnvelope) -> bytes:
    body = {"issuer": envelope.issuer, "key_id": envelope.key_id, "algorithm": envelope.algorithm, "payload": dict(envelope.payload)}
    return json.dumps(body, sort_keys=True, separators=(",", ":")).encode("utf-8")


def verify_signed_envelope(
    envelope: SignedProviderEnvelope,
    *,
    trusted_issuers: Mapping[str, set[str]],
    signature_verifier: Callable[[str, str, str, bytes, str], bool],
    context: VerificationContext,
    now: datetime | None = None,
    consumed_digests: frozenset[str] = frozenset(),
) -> HeartBeatAssertion:
    """Validate provider identity/signature, then the bounded HeartBeat assertion.

    Cryptographic implementation is injected so production can use an approved
    asymmetric/JWS verifier and managed trust store. No biometric material is handled.
    """
    allowed_keys = trusted_issuers.get(envelope.issuer)
    if not allowed_keys or envelope.key_id not in allowed_keys:
        raise ProviderAssertionRejected("untrusted issuer or key")
    if envelope.algorithm.lower() in {"none", "", "hs256", "hs384", "hs512"}:
        raise ProviderAssertionRejected("algorithm not permitted for production provider assertions")
    if not signature_verifier(envelope.issuer, envelope.key_id, envelope.algorithm, canonical_payload(envelope), envelope.signature):
        raise ProviderAssertionRejected("invalid provider signature")

    p = envelope.payload
    required = {"subject_id", "challenge_id", "verification_status", "liveness_status", "assurance_level", "assertion_digest", "issued_at", "expires_at", "sensor_attestation_ref"}
    if not required.issubset(p) or not str(p["sensor_attestation_ref"]).strip():
        raise ProviderAssertionRejected("missing required provider assertion field")
    assertion = HeartBeatAssertion(
        subject_id=str(p["subject_id"]), challenge_id=str(p["challenge_id"]),
        verification_status=str(p["verification_status"]), liveness_status=str(p["liveness_status"]),
        assurance_level=str(p["assurance_level"]), assertion_digest=str(p["assertion_digest"]),
        issued_at=datetime.fromisoformat(str(p["issued_at"])), expires_at=datetime.fromisoformat(str(p["expires_at"])),
        revoked_at=datetime.fromisoformat(str(p["revoked_at"])) if p.get("revoked_at") else None,
    )
    return verify_assertion(assertion, context, now=now or datetime.now(timezone.utc), consumed_digests=consumed_digests)


def insecure_test_hmac_verifier(secret: bytes) -> Callable[[str, str, str, bytes, str], bool]:
    """Test-only verifier. Production envelopes explicitly reject HMAC algorithms."""
    def verify(_issuer: str, _key_id: str, _algorithm: str, message: bytes, signature: str) -> bool:
        expected = hmac.new(secret, message, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)
    return verify
