from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from setc.heartbeat.authorization import (
    HardwareSigningRequest,
    PolicyDecision,
    PolicyEffect,
)
from setc.heartbeat.models import (
    HeartBeatAssertion,
    HeartBeatDecision,
    HeartBeatIdentifiers,
)


def _assertion(**overrides):
    now = datetime.now(timezone.utc)
    values = dict(
        identifiers=HeartBeatIdentifiers(uuid4(), uuid4(), uuid4(), "corr-1"),
        actor_id="actor-1",
        authentication_method="cardiac",
        assurance_level="high",
        match_confidence=0.99,
        liveness_status=HeartBeatDecision.SUCCEEDED,
        continuity_status=HeartBeatDecision.SUCCEEDED,
        device_trust_reference="device-trust-1",
        template_version="template-v1",
        algorithm_version="algorithm-v1",
        policy_version="policy-v1",
        issued_at=now,
        expires_at=now + timedelta(minutes=5),
        integrity_metadata={"sensor_integrity": "passed"},
    )
    values.update(overrides)
    return HeartBeatAssertion(**values)


def test_assertion_accepts_bounded_confidence():
    assertion = _assertion()
    assert assertion.match_confidence == 0.99


def test_assertion_rejects_confidence_outside_unit_interval():
    with pytest.raises(ValueError):
        _assertion(match_confidence=1.01)


def test_assertion_rejects_nonpositive_lifetime():
    now = datetime.now(timezone.utc)
    with pytest.raises(ValueError):
        _assertion(issued_at=now, expires_at=now)


def test_denied_policy_cannot_create_signing_request():
    decision = PolicyDecision(
        decision_id=uuid4(),
        effect=PolicyEffect.DENY,
        actor_id="actor-1",
        assertion_id=uuid4(),
        correlation_id="corr-1",
        requested_action="settlement.release",
        policy_version="policy-v1",
        decided_at=datetime.now(timezone.utc),
        reason_code="insufficient_authority",
    )
    with pytest.raises(PermissionError):
        HardwareSigningRequest.from_policy_decision(
            decision,
            key_reference="hsm-key-1",
            payload_digest="sha256:example",
            requested_at=datetime.now(timezone.utc),
        )


def test_allowed_policy_can_create_signing_request_without_biometric_material():
    decision = PolicyDecision(
        decision_id=uuid4(),
        effect=PolicyEffect.ALLOW,
        actor_id="actor-1",
        assertion_id=uuid4(),
        correlation_id="corr-1",
        requested_action="knowledge.promote",
        policy_version="policy-v1",
        decided_at=datetime.now(timezone.utc),
        reason_code="authorized",
    )
    request = HardwareSigningRequest.from_policy_decision(
        decision,
        key_reference="hsm-key-1",
        payload_digest="sha256:example",
        requested_at=datetime.now(timezone.utc),
    )
    assert request.decision_id == decision.decision_id
    assert not hasattr(request, "template_id")
    assert not hasattr(request, "cardiac_signal")
