"""Event contracts for SETC-HB-001 HeartBeat authentication workflows."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID

from .models import HeartBeatDecision


class HeartBeatEventType(StrEnum):
    ENROLLMENT_COMPLETED = "CardiacEnrollmentCompleted"
    AUTHENTICATION_SUCCEEDED = "CardiacAuthenticationSucceeded"
    AUTHENTICATION_FAILED = "CardiacAuthenticationFailed"
    CONTINUITY_DEGRADED = "CardiacContinuityDegraded"
    CREDENTIAL_REVOKED = "CardiacCredentialRevoked"
    SENSOR_INTEGRITY_FAILED = "CardiacSensorIntegrityFailed"


@dataclass(frozen=True, slots=True)
class HeartBeatEvent:
    event_id: UUID
    event_type: HeartBeatEventType
    actor_id: str
    correlation_id: str
    causation_id: str | None
    assertion_id: UUID | None
    cardiac_credential_id: UUID | None
    occurred_at: datetime
    schema_version: str
    algorithm_version: str
    policy_version: str
    decision: HeartBeatDecision | None
    integrity_metadata: dict[str, str]

    def __post_init__(self) -> None:
        if not self.actor_id.strip():
            raise ValueError("actor_id is required")
        if not self.correlation_id.strip():
            raise ValueError("correlation_id is required")
        if not self.schema_version.strip():
            raise ValueError("schema_version is required")
        if not self.algorithm_version.strip():
            raise ValueError("algorithm_version is required")
        if not self.policy_version.strip():
            raise ValueError("policy_version is required")
