"""Domain contracts for SETC-HB-001 HeartBeat biometric authentication."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID


class HeartBeatCapability(StrEnum):
    CARDIAC_IDENTITY = "SETC-HB-ID"
    PROOF_OF_LIFE = "SETC-HB-LIVE"
    PROOF_OF_CONTINUITY = "SETC-HB-CONT"
    AUTHORITY_BINDING = "SETC-HB-AUTH"


class HeartBeatDecision(StrEnum):
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    DEGRADED = "degraded"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class HeartBeatIdentifiers:
    """Opaque references only; never raw cardiac data or reusable templates."""

    cardiac_credential_id: UUID
    template_id: UUID
    assertion_id: UUID
    correlation_id: str


@dataclass(frozen=True, slots=True)
class HeartBeatAssertion:
    """Bounded authentication assertion required by SETC-HB-001 section 9."""

    identifiers: HeartBeatIdentifiers
    actor_id: str
    authentication_method: str
    assurance_level: str
    match_confidence: float
    liveness_status: HeartBeatDecision
    continuity_status: HeartBeatDecision | None
    device_trust_reference: str
    template_version: str
    algorithm_version: str
    policy_version: str
    issued_at: datetime
    expires_at: datetime
    integrity_metadata: dict[str, str]

    def __post_init__(self) -> None:
        if not 0.0 <= self.match_confidence <= 1.0:
            raise ValueError("match_confidence must be between 0 and 1")
        if self.expires_at <= self.issued_at:
            raise ValueError("expires_at must be after issued_at")
