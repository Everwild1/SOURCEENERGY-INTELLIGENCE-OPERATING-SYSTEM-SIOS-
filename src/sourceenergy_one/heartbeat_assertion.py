from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import FrozenSet


@dataclass(frozen=True)
class HeartBeatAssertion:
    subject_id: str
    challenge_id: str
    verification_status: str
    liveness_status: str
    assurance_level: str
    assertion_digest: str
    issued_at: datetime
    expires_at: datetime
    revoked_at: datetime | None = None


@dataclass(frozen=True)
class VerificationContext:
    expected_subject_id: str
    expected_challenge_id: str
    minimum_assurance: str = "standard"
    require_liveness: bool = False


class AssertionRejected(ValueError):
    pass


_ASSURANCE = {"standard": 1, "elevated": 2, "institutional": 3}


def verify_assertion(
    assertion: HeartBeatAssertion,
    context: VerificationContext,
    *,
    now: datetime | None = None,
    consumed_digests: FrozenSet[str] = frozenset(),
) -> HeartBeatAssertion:
    """Fail-closed validation of a bounded HeartBeatID assertion.

    This function consumes assertion metadata only. Raw physiological signals and
    reusable biometric templates are outside the SourceEnergy One boundary.
    Successful verification authenticates a factor; it does not authorize an action.
    """
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise AssertionRejected("current time must be timezone-aware")
    if assertion.subject_id != context.expected_subject_id:
        raise AssertionRejected("subject mismatch")
    if assertion.challenge_id != context.expected_challenge_id:
        raise AssertionRejected("challenge mismatch")
    if assertion.assertion_digest in consumed_digests:
        raise AssertionRejected("assertion replay detected")
    if assertion.verification_status != "verified":
        raise AssertionRejected("identity not verified")
    if context.require_liveness and assertion.liveness_status != "passed":
        raise AssertionRejected("required liveness not satisfied")
    if assertion.revoked_at is not None and assertion.revoked_at <= now:
        raise AssertionRejected("assertion revoked")
    if assertion.issued_at > now:
        raise AssertionRejected("assertion issued in the future")
    if assertion.expires_at <= now:
        raise AssertionRejected("assertion expired")
    actual = _ASSURANCE.get(assertion.assurance_level, 0)
    required = _ASSURANCE.get(context.minimum_assurance)
    if required is None or actual < required:
        raise AssertionRejected("insufficient assurance")
    if not assertion.assertion_digest.strip():
        raise AssertionRejected("missing assertion digest")
    return assertion
