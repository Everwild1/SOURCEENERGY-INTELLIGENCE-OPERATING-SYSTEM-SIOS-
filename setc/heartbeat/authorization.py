"""IAM/PDP, hardware-signing, and AuditLedger boundary contracts.

HeartBeat supplies authentication evidence only. These contracts deliberately
require an independent policy decision before any signing request is emitted.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID


class PolicyEffect(StrEnum):
    ALLOW = "allow"
    DENY = "deny"
    STEP_UP = "step_up"


@dataclass(frozen=True, slots=True)
class AuthorizationContext:
    actor_id: str
    assertion_id: UUID
    correlation_id: str
    requested_action: str
    resource_reference: str
    role_references: tuple[str, ...]
    delegation_references: tuple[str, ...]
    policy_version: str


@dataclass(frozen=True, slots=True)
class PolicyDecision:
    decision_id: UUID
    effect: PolicyEffect
    actor_id: str
    assertion_id: UUID
    correlation_id: str
    requested_action: str
    policy_version: str
    decided_at: datetime
    reason_code: str

    @property
    def permits_signing(self) -> bool:
        return self.effect is PolicyEffect.ALLOW


@dataclass(frozen=True, slots=True)
class HardwareSigningRequest:
    """A signing request may only be constructed from an independent ALLOW."""

    decision_id: UUID
    actor_id: str
    correlation_id: str
    key_reference: str
    payload_digest: str
    requested_at: datetime

    @classmethod
    def from_policy_decision(
        cls,
        decision: PolicyDecision,
        *,
        key_reference: str,
        payload_digest: str,
        requested_at: datetime,
    ) -> "HardwareSigningRequest":
        if not decision.permits_signing:
            raise PermissionError("policy decision does not permit signing")
        return cls(
            decision_id=decision.decision_id,
            actor_id=decision.actor_id,
            correlation_id=decision.correlation_id,
            key_reference=key_reference,
            payload_digest=payload_digest,
            requested_at=requested_at,
        )


@dataclass(frozen=True, slots=True)
class HeartBeatAuditAttestation:
    """Ledger-safe references; never raw cardiac signals or biometric templates."""

    event_id: UUID
    actor_id: str
    assertion_id: UUID
    policy_decision_id: UUID | None
    correlation_id: str
    event_type: str
    outcome: str
    occurred_at: datetime
    algorithm_version: str
    policy_version: str
    integrity_digest: str
