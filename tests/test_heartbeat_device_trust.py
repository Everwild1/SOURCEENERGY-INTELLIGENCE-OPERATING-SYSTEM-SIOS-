from datetime import datetime, timedelta, timezone

import pytest

from setc.heartbeat.device_trust import (
    DeviceTrustDecision,
    SensorIntegrityEvidence,
)


def evidence(decision=DeviceTrustDecision.TRUSTED):
    now = datetime.now(timezone.utc)
    return SensorIntegrityEvidence(
        sensor_reference="sensor:cardiac:001",
        device_reference="device:secure:001",
        attestation_reference="attestation:001",
        firmware_version="1.0.0",
        trust_policy_version="SETC-HB-DEVICE-1",
        decision=decision,
        evaluated_at=now,
        expires_at=now + timedelta(minutes=5),
        integrity_digest="sha256:test",
    )


def test_trusted_device_evidence_is_usable():
    item = evidence()
    item.assert_usable(now=item.evaluated_at + timedelta(seconds=1))


@pytest.mark.parametrize(
    "decision",
    [DeviceTrustDecision.DEGRADED, DeviceTrustDecision.UNTRUSTED, DeviceTrustDecision.REVOKED],
)
def test_nontrusted_device_evidence_fails_closed(decision):
    item = evidence(decision)
    with pytest.raises(PermissionError):
        item.assert_usable(now=item.evaluated_at + timedelta(seconds=1))


def test_expired_device_evidence_fails_closed():
    item = evidence()
    with pytest.raises(PermissionError):
        item.assert_usable(now=item.expires_at)
