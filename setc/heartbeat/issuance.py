"""Assertion issuance gate for SETC-HB-001.

A biometric assertion may be issued only after sensor/device evidence has been
validated. The returned binding is a bounded integrity reference; it contains
no raw cardiac signal or reusable biometric template material.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from .device_trust import SensorIntegrityEvidence


@dataclass(frozen=True, slots=True)
class AssertionIntegrityBinding:
    device_reference: str
    sensor_reference: str
    device_attestation_reference: str
    device_integrity_digest: str
    device_trust_policy_version: str


def bind_device_evidence_for_assertion(
    evidence: SensorIntegrityEvidence,
    *,
    now: datetime,
) -> AssertionIntegrityBinding:
    """Validate device evidence and return ledger-safe assertion references."""
    evidence.assert_usable(now=now)
    return AssertionIntegrityBinding(
        device_reference=evidence.device_reference,
        sensor_reference=evidence.sensor_reference,
        device_attestation_reference=evidence.attestation_reference,
        device_integrity_digest=evidence.integrity_digest,
        device_trust_policy_version=evidence.trust_policy_version,
    )
