from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from setc.heartbeat.continuity import CredentialStatus, ContinuityContext, assert_usable_for_authorization
from setc.heartbeat.models import HeartBeatAssertion, HeartBeatDecision, HeartBeatIdentifiers


def assertion() -> HeartBeatAssertion:
    now = datetime.now(timezone.utc)
    return HeartBeatAssertion(
        identifiers=HeartBeatIdentifiers(uuid4(), uuid4(), uuid4(), "corr-1"),
        actor_id="actor-1",
        authentication_method="cardiac",
        assurance_level="high",
        match_confidence=0.99,
        liveness_status=HeartBeatDecision.SUCCEEDED,
        continuity_status=HeartBeatDecision.SUCCEEDED,
        device_trust_reference="device-1",
        template_version="1",
        algorithm_version="1",
        policy_version="1",
        issued_at=now,
        expires_at=now + timedelta(minutes=5),
        integrity_metadata={},
    )


def test_active_continuity_passes():
    hb = assertion()
    ctx = ContinuityContext(CredentialStatus.ACTIVE, HeartBeatDecision.SUCCEEDED, hb.issued_at)
    assert_usable_for_authorization(hb, ctx, now=hb.issued_at + timedelta(seconds=1))


@pytest.mark.parametrize("status", [CredentialStatus.SUSPENDED, CredentialStatus.REVOKED])
def test_non_active_credential_fails_closed(status):
    hb = assertion()
    ctx = ContinuityContext(status, HeartBeatDecision.SUCCEEDED, hb.issued_at)
    with pytest.raises(PermissionError):
        assert_usable_for_authorization(hb, ctx, now=hb.issued_at + timedelta(seconds=1))


@pytest.mark.parametrize("continuity", [HeartBeatDecision.FAILED, HeartBeatDecision.DEGRADED, HeartBeatDecision.REVOKED])
def test_bad_continuity_requires_re_evaluation(continuity):
    hb = assertion()
    ctx = ContinuityContext(CredentialStatus.ACTIVE, continuity, hb.issued_at)
    with pytest.raises(PermissionError):
        assert_usable_for_authorization(hb, ctx, now=hb.issued_at + timedelta(seconds=1))


def test_expired_assertion_fails_closed():
    hb = assertion()
    ctx = ContinuityContext(CredentialStatus.ACTIVE, HeartBeatDecision.SUCCEEDED, hb.issued_at)
    with pytest.raises(PermissionError):
        assert_usable_for_authorization(hb, ctx, now=hb.expires_at)
