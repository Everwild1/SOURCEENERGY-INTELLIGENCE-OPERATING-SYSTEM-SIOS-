"""Canonical Source Coin domain primitives for SC-E01/02/04."""

from dataclasses import dataclass
from enum import Enum
from typing import Optional
from uuid import UUID

from setc.core import SETCIdentifier


class AccountStatus(str, Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    FROZEN = "FROZEN"
    CLOSED = "CLOSED"


class WalletRole(str, Enum):
    VIEWER = "VIEWER"
    INITIATOR = "INITIATOR"
    APPROVER = "APPROVER"
    SIGNER = "SIGNER"
    TREASURY_OPERATOR = "TREASURY_OPERATOR"
    AUDITOR = "AUDITOR"


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
    organization_id: SETCIdentifier
    status: AccountStatus = AccountStatus.ACTIVE

    @property
    def can_transact(self) -> bool:
        return self.status is AccountStatus.ACTIVE


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
        if self.transaction_type in {
            TransactionType.TRANSFER,
            TransactionType.TREASURY_ALLOCATION,
            TransactionType.SETTLEMENT,
            TransactionType.REWARD,
        }:
            if self.source_account_id is None or self.destination_account_id is None:
                raise ValueError("transfer-like transactions require source and destination accounts")
            if self.source_account_id == self.destination_account_id:
                raise ValueError("source and destination accounts must differ")
        if self.transaction_type is TransactionType.MINT and self.destination_account_id is None:
            raise ValueError("mint requires a destination account")
        if self.transaction_type is TransactionType.BURN and self.source_account_id is None:
            raise ValueError("burn requires a source account")


@dataclass(frozen=True)
class OrganizationWallet:
    wallet_id: UUID
    organization_id: SETCIdentifier
    account_id: UUID
    status: AccountStatus = AccountStatus.ACTIVE


@dataclass(frozen=True)
class WalletAuthorization:
    authorization_id: UUID
    wallet_id: UUID
    principal_ref: str
    role: WalletRole
    active: bool = True

    def __post_init__(self) -> None:
        if not self.principal_ref.strip():
            raise ValueError("principal_ref is required")
