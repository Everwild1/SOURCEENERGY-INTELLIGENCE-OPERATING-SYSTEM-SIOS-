"""IAM/PDP, hardware-signing, and AuditLedger boundary contracts.

HeartBeat supplies authentication evidence only. These contracts deliberately
require an independent policy decision before any signing request is emitted.
Trusted device integrity is carried as bounded evidence throughout the flow;
it is neither human identity nor substantive authority.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID

from .issuance import AssertionIntegrityBinding


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
    integrity_binding: AssertionIntegrityBinding


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
    integrity_binding: AssertionIntegrityBinding

    @classmethod
    def from_context(
        cls,
        context: AuthorizationContext,
        *,
        decision_id: UUID,
        effect: PolicyEffect,
        decided_at: datetime,
        reason_code: str,
    ) -> "PolicyDecision":
        return cls(
            decision_id=decision_id,
            effect=effect,
            actor_id=context.actor_id,
            assertion_id=context.assertion_id,
            correlation_id=context.correlation_id,
            requested_action=context.requested_action,
            policy_version=context.policy_version,
            decided_at=decided_at,
            reason_code=reason_code,
            integrity_binding=context.integrity_binding,
        )

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
    device_attestation_reference: str
    device_integrity_digest: str
    device_trust_policy_version: str

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
        binding = decision.integrity_binding
        return cls(
            decision_id=decision.decision_id,
            actor_id=decision.actor_id,
            correlation_id=decision.correlation_id,
            key_reference=key_reference,
            payload_digest=payload_digest,
            requested_at=requested_at,
            device_attestation_reference=binding.device_attestation_reference,
            device_integrity_digest=binding.device_integrity_digest,
            device_trust_policy_version=binding.device_trust_policy_version,
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
    device_attestation_reference: str
    device_integrity_digest: str
    device_trust_policy_version: str

    @classmethod
    def from_policy_decision(
        cls,
        decision: PolicyDecision,
        *,
        event_id: UUID,
        event_type: str,
        outcome: str,
        occurred_at: datetime,
        algorithm_version: str,
        integrity_digest: str,
    ) -> "HeartBeatAuditAttestation":
        binding = decision.integrity_binding
        return cls(
            event_id=event_id,
            actor_id=decision.actor_id,
            assertion_id=decision.assertion_id,
            policy_decision_id=decision.decision_id,
            correlation_id=decision.correlation_id,
            event_type=event_type,
            outcome=outcome,
            occurred_at=occurred_at,
            algorithm_version=algorithm_version,
            policy_version=decision.policy_version,
            integrity_digest=integrity_digest,
            device_attestation_reference=binding.device_attestation_reference,
            device_integrity_digest=binding.device_integrity_digest,
            device_trust_policy_version=binding.device_trust_policy_version,
        )
