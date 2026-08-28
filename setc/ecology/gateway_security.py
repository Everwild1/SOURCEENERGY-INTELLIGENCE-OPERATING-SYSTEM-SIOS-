"""ECO-PH-03 production-facing security controls for the Ecology gateway.

These controls authenticate and authorize transport requests, enforce replay and
rate policies, and emit audit decisions. They never execute source-domain work.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Mapping

from .domain import EcologyDomain
from .gateway import GatewayAction, GatewayRequest, GatewayReceipt, ReceiptStatus, allowed_actions


class GatewayDecision(str, Enum):
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class GatewayRejection(str, Enum):
    UNAUTHENTICATED = "unauthenticated"
    UNAUTHORIZED = "unauthorized"
    REPLAY = "replay"
    RATE_LIMITED = "rate_limited"


@dataclass(frozen=True)
class GatewayPrincipal:
    principal_id: str
    authenticated: bool
    permissions: Mapping[EcologyDomain, frozenset[GatewayAction]] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.principal_id.strip():
            raise ValueError("principal_id is required")

    def permits(self, domain: EcologyDomain, action: GatewayAction) -> bool:
        return self.authenticated and action in self.permissions.get(domain, frozenset()) and action in allowed_actions(domain)


@dataclass(frozen=True)
class GatewayAuditRecord:
    request_id: str
    principal_id: str
    target_domain: EcologyDomain
    action: GatewayAction
    correlation_id: str
    decision: GatewayDecision
    rejection: GatewayRejection | None
    recorded_at: datetime

    @property
    def confers_source_authority(self) -> bool:
        return False

    @property
    def proves_execution(self) -> bool:
        return False


@dataclass(frozen=True)
class GatewaySecurityResult:
    receipt: GatewayReceipt
    audit: GatewayAuditRecord


class InMemoryGatewaySecurity:
    """Deterministic reference enforcement store for gateway adapters and tests."""

    def __init__(self, rate_limit: int = 100) -> None:
        if rate_limit <= 0:
            raise ValueError("rate_limit must be positive")
        self.rate_limit = rate_limit
        self._idempotency: set[str] = set()
        self._principal_counts: dict[str, int] = {}

    def evaluate(self, request: GatewayRequest, principal: GatewayPrincipal, now: datetime | None = None) -> GatewaySecurityResult:
        now = now or datetime.now(timezone.utc)
        if now.tzinfo is None:
            raise ValueError("now must be timezone-aware")

        rejection: GatewayRejection | None = None
        if not principal.authenticated:
            rejection = GatewayRejection.UNAUTHENTICATED
        elif not principal.permits(request.target_domain, request.action):
            rejection = GatewayRejection.UNAUTHORIZED
        else:
            count = self._principal_counts.get(principal.principal_id, 0)
            if count >= self.rate_limit:
                rejection = GatewayRejection.RATE_LIMITED
            elif request.correlation.idempotency_key and request.correlation.idempotency_key in self._idempotency:
                rejection = GatewayRejection.REPLAY

        accepted = rejection is None
        if accepted:
            self._principal_counts[principal.principal_id] = self._principal_counts.get(principal.principal_id, 0) + 1
            if request.correlation.idempotency_key:
                self._idempotency.add(request.correlation.idempotency_key)

        decision = GatewayDecision.ACCEPTED if accepted else GatewayDecision.REJECTED
        receipt = GatewayReceipt(
            receipt_id=f"gateway-security:{request.request_id}:{decision.value}",
            request_id=request.request_id,
            target_domain=request.target_domain,
            status=ReceiptStatus.ACCEPTED_FOR_REVIEW if accepted else ReceiptStatus.REJECTED,
            received_at=now,
            message=None if accepted else rejection.value,
        )
        audit = GatewayAuditRecord(
            request_id=request.request_id,
            principal_id=principal.principal_id,
            target_domain=request.target_domain,
            action=request.action,
            correlation_id=request.correlation.correlation_id,
            decision=decision,
            rejection=rejection,
            recorded_at=now,
        )
        return GatewaySecurityResult(receipt=receipt, audit=audit)
