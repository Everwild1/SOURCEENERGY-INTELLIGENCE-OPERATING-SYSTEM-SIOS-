"""SC-E03 treasury and supply governance primitives.

These objects model authority; they do not enable production minting or burning.
"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional
from uuid import UUID


class SupplyMode(str, Enum):
    FIXED_GENESIS = "FIXED_GENESIS"
    CAPPED = "CAPPED"
    SCHEDULED = "SCHEDULED"
    GOVERNED = "GOVERNED"


class TreasuryStatus(str, Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    CLOSED = "CLOSED"


@dataclass(frozen=True)
class SupplyPolicy:
    policy_id: UUID
    version: str
    mode: SupplyMode
    approved: bool = False
    max_supply_minor: Optional[int] = None
    per_period_limit_minor: Optional[int] = None

    def __post_init__(self) -> None:
        if not self.version.strip():
            raise ValueError("version is required")
        if self.max_supply_minor is not None and self.max_supply_minor <= 0:
            raise ValueError("max_supply_minor must be positive")
        if self.per_period_limit_minor is not None and self.per_period_limit_minor <= 0:
            raise ValueError("per_period_limit_minor must be positive")
        if self.mode is SupplyMode.CAPPED and self.max_supply_minor is None:
            raise ValueError("CAPPED policy requires max_supply_minor")

    def permits_supply(self, current_supply_minor: int, requested_minor: int) -> bool:
        if not self.approved or requested_minor <= 0:
            return False
        if self.max_supply_minor is not None and current_supply_minor + requested_minor > self.max_supply_minor:
            return False
        if self.per_period_limit_minor is not None and requested_minor > self.per_period_limit_minor:
            return False
        return True


@dataclass(frozen=True)
class TreasuryAccount:
    treasury_account_id: UUID
    coin_account_id: UUID
    purpose: str
    status: TreasuryStatus = TreasuryStatus.ACTIVE

    def __post_init__(self) -> None:
        if not self.purpose.strip():
            raise ValueError("purpose is required")


@dataclass(frozen=True)
class TreasuryAuthorization:
    authorization_id: UUID
    policy_id: UUID
    proposer_ref: str
    approver_ref: str
    amount_minor: int
    purpose: str
    approved: bool = False

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("amount_minor must be positive")
        if not self.proposer_ref.strip() or not self.approver_ref.strip():
            raise ValueError("proposer_ref and approver_ref are required")
        if self.proposer_ref == self.approver_ref:
            raise ValueError("separation of duties requires distinct proposer and approver")
        if not self.purpose.strip():
            raise ValueError("purpose is required")


@dataclass(frozen=True)
class TreasuryAllocation:
    allocation_id: UUID
    treasury_account_id: UUID
    destination_account_id: UUID
    amount_minor: int
    authorization_id: UUID
    policy_id: UUID

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("amount_minor must be positive")


def reconcile_supply(total_minted_minor: int, total_burned_minor: int) -> int:
    """Return deterministic circulating supply from authorized supply events."""
    if total_minted_minor < 0 or total_burned_minor < 0:
        raise ValueError("supply event totals cannot be negative")
    if total_burned_minor > total_minted_minor:
        raise ValueError("burned supply cannot exceed minted supply")
    return total_minted_minor - total_burned_minor
