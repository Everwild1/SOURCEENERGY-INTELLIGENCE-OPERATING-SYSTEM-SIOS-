"""SC-E08 contract-first API and domain event primitives."""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Mapping, Optional
from uuid import UUID, uuid4


API_VERSION = "v1"
SCHEMA_VERSION = "1.0"


class ErrorCode(str, Enum):
    VALIDATION_FAILED = "VALIDATION_FAILED"
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    INELIGIBLE = "INELIGIBLE"
    POLICY_DENIED = "POLICY_DENIED"
    INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS"
    DUPLICATE_REQUEST = "DUPLICATE_REQUEST"
    CONFLICT = "CONFLICT"
    EXPIRED = "EXPIRED"
    RATE_LIMITED = "RATE_LIMITED"
    CONTROL_UNAVAILABLE = "CONTROL_UNAVAILABLE"
    INTERNAL_ERROR = "INTERNAL_ERROR"


class DomainEventType(str, Enum):
    ACCOUNT_CREATED = "CoinAccountCreated"
    ACCOUNT_STATUS_CHANGED = "CoinAccountStatusChanged"
    ORGANIZATION_WALLET_CREATED = "OrganizationWalletCreated"
    WALLET_AUTHORIZATION_GRANTED = "WalletAuthorizationGranted"
    WALLET_AUTHORIZATION_REVOKED = "WalletAuthorizationRevoked"
    TRANSACTION_CREATED = "TransactionCreated"
    TRANSACTION_AUTHORIZED = "TransactionAuthorized"
    TRANSACTION_SETTLED = "TransactionSettled"
    TRANSACTION_FAILED = "TransactionFailed"
    SETTLEMENT_CREATED = "SettlementInstructionCreated"
    SETTLEMENT_SETTLED = "SettlementSettled"
    REWARD_APPROVED = "RewardGrantApproved"
    REWARD_EXECUTED = "RewardGrantExecuted"
    TREASURY_ALLOCATION_AUTHORIZED = "TreasuryAllocationAuthorized"
    TREASURY_ALLOCATION_EXECUTED = "TreasuryAllocationExecuted"
    COMPLIANCE_DECISION_RECORDED = "ComplianceDecisionRecorded"
    RECONCILIATION_EXCEPTION = "LedgerReconciliationExceptionDetected"


@dataclass(frozen=True)
class RequestEnvelope:
    request_id: UUID
    correlation_id: str
    idempotency_key: str
    actor_ref: str
    organization_ref: Optional[str] = None
    api_version: str = API_VERSION
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def __post_init__(self) -> None:
        for value, name in (
            (self.correlation_id, "correlation_id"),
            (self.idempotency_key, "idempotency_key"),
            (self.actor_ref, "actor_ref"),
        ):
            if not value.strip():
                raise ValueError(f"{name} is required")
        if self.api_version != API_VERSION:
            raise ValueError("unsupported API version")


@dataclass(frozen=True)
class DomainEvent:
    event_type: DomainEventType
    aggregate_type: str
    aggregate_id: str
    correlation_id: str
    payload: Mapping[str, Any]
    event_id: UUID = field(default_factory=uuid4)
    causation_id: Optional[str] = None
    organization_ref: Optional[str] = None
    policy_ref: Optional[str] = None
    schema_version: str = SCHEMA_VERSION
    occurred_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def __post_init__(self) -> None:
        if not self.aggregate_type.strip() or not self.aggregate_id.strip():
            raise ValueError("aggregate identity is required")
        if not self.correlation_id.strip():
            raise ValueError("correlation_id is required")
        if self.schema_version != SCHEMA_VERSION:
            raise ValueError("unsupported schema version")


@dataclass(frozen=True)
class APIError:
    code: ErrorCode
    message: str
    correlation_id: str
    details: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.message.strip() or not self.correlation_id.strip():
            raise ValueError("message and correlation_id are required")
