"""Sensor/device trust evidence for SETC-HB-001 authentication.

Device trust is authentication evidence, not identity and not substantive
authority. NASA/third-party technology provenance remains a separate governed
IP/licensing concern and is never encoded as an actor credential.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class DeviceTrustDecision(StrEnum):
    TRUSTED = "trusted"
    DEGRADED = "degraded"
    UNTRUSTED = "untrusted"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class SensorIntegrityEvidence:
    sensor_reference: str
    device_reference: str
    attestation_reference: str
    firmware_version: str
    trust_policy_version: str
    decision: DeviceTrustDecision
    evaluated_at: datetime
    expires_at: datetime
    integrity_digest: str

    def __post_init__(self) -> None:
        required = (
            self.sensor_reference,
            self.device_reference,
            self.attestation_reference,
            self.firmware_version,
            self.trust_policy_version,
            self.integrity_digest,
        )
        if any(not value.strip() for value in required):
            raise ValueError("device trust references and versions are required")
        if self.expires_at <= self.evaluated_at:
            raise ValueError("device trust evidence must have a positive lifetime")

    def assert_usable(self, *, now: datetime) -> None:
        if self.decision is not DeviceTrustDecision.TRUSTED:
            raise PermissionError("sensor/device trust requirement not satisfied")
        if now >= self.expires_at:
            raise PermissionError("sensor/device trust evidence has expired")
