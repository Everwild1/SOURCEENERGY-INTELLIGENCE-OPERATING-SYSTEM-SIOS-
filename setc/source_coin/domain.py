"""Canonical Source Coin Sprint 1 domain primitives."""

from dataclasses import dataclass
from enum import Enum
from typing import Optional
from uuid import UUID


class AccountStatus(str, Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    FROZEN = "FROZEN"
    CLOSED = "CLOSED"


class TransactionType(str, Enum):
    TRANSFER = "TRANSFER"
    MINT = "MINT"
    BURN = "BURN"
    TREASURY_ALLOCATION = "TREASURY_ALLOCATION"
    SETTLEMENT = "SETTLEMENT"
    REWARD = "REWARD"


class TransactionStatus(str, Enum):
    CREATED = "CREATED"
    VALIDATED = "VALIDATED"
    AUTHORIZED = "AUTHORIZED"
    EXECUTING = "EXECUTING"
    SETTLED = "SETTLED"
    REJECTED = "REJECTED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


@dataclass(frozen=True)
class CoinAccount:
    account_id: UUID
    organization_id: UUID
    status: AccountStatus = AccountStatus.ACTIVE


@dataclass(frozen=True)
class CoinTransaction:
    transaction_id: UUID
    asset_id: UUID
    transaction_type: TransactionType
    amount_minor: int
    idempotency_key: str
    correlation_id: str
    source_account_id: Optional[UUID] = None
    destination_account_id: Optional[UUID] = None
    authorization_ref: Optional[str] = None
    policy_decision_ref: Optional[str] = None
    status: TransactionStatus = TransactionStatus.CREATED

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("amount_minor must be positive")
        if not self.idempotency_key.strip():
            raise ValueError("idempotency_key is required")
        if not self.correlation_id.strip():
            raise ValueError("correlation_id is required")


@dataclass(frozen=True)
class OrganizationWallet:
    wallet_id: UUID
    organization_id: UUID
    account_id: UUID
    status: AccountStatus = AccountStatus.ACTIVE
