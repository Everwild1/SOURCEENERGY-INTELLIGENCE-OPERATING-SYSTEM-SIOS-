"""SC-E09 executable security and economic invariants."""

from dataclasses import dataclass
from enum import Enum
from typing import Iterable

from .domain import CoinTransaction, TransactionStatus, TransactionType


class EmergencyState(str, Enum):
    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"


PRIVILEGED_TYPES = {TransactionType.MINT, TransactionType.BURN}


@dataclass(frozen=True)
class EconomicSnapshot:
    authorized_genesis_minor: int
    authorized_mint_minor: int
    authorized_burn_minor: int
    observed_supply_minor: int

    def expected_supply_minor(self) -> int:
        return self.authorized_genesis_minor + self.authorized_mint_minor - self.authorized_burn_minor

    def supply_is_conserved(self) -> bool:
        return self.observed_supply_minor == self.expected_supply_minor()


def assert_supply_conservation(snapshot: EconomicSnapshot) -> None:
    if min(
        snapshot.authorized_genesis_minor,
        snapshot.authorized_mint_minor,
        snapshot.authorized_burn_minor,
        snapshot.observed_supply_minor,
    ) < 0:
        raise ValueError("supply components must be non-negative")
    if not snapshot.supply_is_conserved():
        raise ValueError("supply invariant violated")


def assert_transfer_conservation(debit_minor: int, credit_minor: int) -> None:
    if debit_minor <= 0 or credit_minor <= 0:
        raise ValueError("transfer legs must be positive")
    if debit_minor != credit_minor:
        raise ValueError("transfer conservation invariant violated")


def assert_no_duplicate_settlement(transactions: Iterable[CoinTransaction]) -> None:
    settled_keys: set[str] = set()
    for transaction in transactions:
        if transaction.status is not TransactionStatus.SETTLED:
            continue
        if transaction.idempotency_key in settled_keys:
            raise ValueError("duplicate settled economic execution detected")
        settled_keys.add(transaction.idempotency_key)


def assert_participant_operation_allowed(transaction_type: TransactionType) -> None:
    if transaction_type in PRIVILEGED_TYPES:
        raise PermissionError("privileged economic operation is isolated from participant execution")


def assert_emergency_state_allows_execution(state: EmergencyState) -> None:
    if state is EmergencyState.PAUSED:
        raise PermissionError("Source Coin economic execution is paused")
