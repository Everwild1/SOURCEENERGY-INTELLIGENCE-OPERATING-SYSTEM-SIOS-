"""SC-E05 governed Source Coin settlement primitives."""

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from uuid import UUID

from .compliance import ComplianceDecision


class SettlementClass(str, Enum):
    INSTITUTIONAL = "INSTITUTIONAL"
    PROGRAM = "PROGRAM"
    RESEARCH = "RESEARCH"
    SOURCE_BLOCK = "SOURCE_BLOCK"
    TREASURY = "TREASURY"
    SERVICE = "SERVICE"


class SettlementStatus(str, Enum):
    CREATED = "CREATED"
    AUTHORIZED = "AUTHORIZED"
    SETTLED = "SETTLED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    FAILED = "FAILED"


@dataclass(frozen=True)
class SettlementInstruction:
    settlement_id: UUID
    settlement_class: SettlementClass
    source_account_id: UUID
    destination_account_id: UUID
    amount_minor: int
    obligation_ref: str
    policy_ref: str
    compliance_decision: ComplianceDecision
    authorization_ref: str
    idempotency_key: str
    expires_at: datetime
    status: SettlementStatus = SettlementStatus.CREATED

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("amount_minor must be positive")
        if self.source_account_id == self.destination_account_id:
            raise ValueError("source and destination accounts must differ")
        for value, name in (
            (self.obligation_ref, "obligation_ref"),
            (self.policy_ref, "policy_ref"),
            (self.authorization_ref, "authorization_ref"),
            (self.idempotency_key, "idempotency_key"),
        ):
            if not value.strip():
                raise ValueError(f"{name} is required")

    def is_expired(self, now: datetime | None = None) -> bool:
        now = now or datetime.now(timezone.utc)
        boundary = self.expires_at
        if boundary.tzinfo is None:
            boundary = boundary.replace(tzinfo=timezone.utc)
        return now > boundary

    def can_execute(self, now: datetime | None = None) -> bool:
        return (
            self.status in {SettlementStatus.CREATED, SettlementStatus.AUTHORIZED}
            and not self.is_expired(now)
            and self.compliance_decision.permits_execution()
        )


def reconcile_settlement(*, instruction: SettlementInstruction, transaction_settled: bool) -> bool:
    """Settlement evidence reconciles only when the instruction and ledger agree."""
    return instruction.status is SettlementStatus.SETTLED and transaction_settled
