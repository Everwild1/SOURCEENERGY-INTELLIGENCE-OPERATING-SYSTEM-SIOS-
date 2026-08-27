from datetime import datetime, timedelta, timezone

import pytest

from setc.heartbeat.device_trust import DeviceTrustDecision, SensorIntegrityEvidence
from setc.heartbeat.issuance import bind_device_evidence_for_assertion


def evidence(decision: DeviceTrustDecision = DeviceTrustDecision.TRUSTED):
    now = datetime.now(timezone.utc)
    return now, SensorIntegrityEvidence(
        sensor_reference="sensor:cardiac:001",
        device_reference="device:secure:001",
        attestation_reference="attestation:001",
        firmware_version="1.0.0",
        trust_policy_version="SETC-HB-DEVICE-1",
        decision=decision,
        evaluated_at=now - timedelta(seconds=5),
        expires_at=now + timedelta(minutes=2),
        integrity_digest="sha256:bounded-integrity-reference",
    )


def test_trusted_device_evidence_binds_to_assertion():
    now, item = evidence()
    binding = bind_device_evidence_for_assertion(item, now=now)
    assert binding.device_attestation_reference == "attestation:001"
    assert binding.device_integrity_digest.startswith("sha256:")
    assert not hasattr(binding, "raw_cardiac_signal")
    assert not hasattr(binding, "biometric_template")


def test_untrusted_device_evidence_cannot_bind_to_assertion():
    now, item = evidence(DeviceTrustDecision.UNTRUSTED)
    with pytest.raises(PermissionError):
        bind_device_evidence_for_assertion(item, now=now)
