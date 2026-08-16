"""Institutional finance and treasury primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from setc.core import SETCIdentifier


class AccountType(StrEnum):
    OPERATING = "OPERATING"
    RESERVE = "RESERVE"
    RESTRICTED = "RESTRICTED"
    ESCROW = "ESCROW"
    CUSTODIAL = "CUSTODIAL"


class TreasuryPositionState(StrEnum):
    REPORTED = "REPORTED"
    RECONCILED = "RECONCILED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"


class DisbursementState(StrEnum):
    REQUESTED = "REQUESTED"
    APPROVED = "APPROVED"
    RELEASED = "RELEASED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


@dataclass(frozen=True, slots=True)
class TreasuryAccount:
    account_id: SETCIdentifier
    organization_id: SETCIdentifier
    account_reference: str
    account_type: AccountType
    custodian_organization_id: SETCIdentifier
    currency: str
    restricted: bool = False

    def __post_init__(self) -> None:
        if not self.account_reference.strip() or not self.currency.strip():
            raise ValueError("treasury account requires reference and currency")


@dataclass(frozen=True, slots=True)
class FundingSource:
    funding_source_id: SETCIdentifier
    organization_id: SETCIdentifier
    source_reference: str
    amount: Decimal
    currency: str
    restricted_purpose: str | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.source_reference.strip() or not self.currency.strip():
            raise ValueError("funding source requires reference and currency")
        if self.amount < 0:
            raise ValueError("funding source amount cannot be negative")
        if self.restricted_purpose is not None and not self.restricted_purpose.strip():
            raise ValueError("restricted_purpose cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class BudgetAllocation:
    allocation_id: SETCIdentifier
    organization_id: SETCIdentifier
    budget_reference: str
    purpose: str
    amount: Decimal
    currency: str
    authorized_by_organization_id: SETCIdentifier
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.budget_reference.strip() or not self.purpose.strip() or not self.currency.strip():
            raise ValueError("budget allocation requires budget, purpose, and currency")
        if self.amount < 0:
            raise ValueError("allocation amount cannot be negative")
        if not self.evidence_reference.strip():
            raise ValueError("budget allocation requires evidence")


@dataclass(frozen=True, slots=True)
class TreasuryPosition:
    position_id: SETCIdentifier
    account_id: SETCIdentifier
    reported_balance: Decimal
    currency: str
    as_of: datetime
    state: TreasuryPositionState = TreasuryPositionState.REPORTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.currency.strip():
            raise ValueError("treasury position currency cannot be blank")
        if self.state == TreasuryPositionState.VERIFIED and not self.evidence_references:
            raise ValueError("verified treasury position requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("treasury evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class FinancialCommitment:
    commitment_id: SETCIdentifier
    organization_id: SETCIdentifier
    counterparty_organization_id: SETCIdentifier
    purpose: str
    amount: Decimal
    currency: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.organization_id == self.counterparty_organization_id:
            raise ValueError("financial commitment requires distinct counterparties")
        if not self.purpose.strip() or not self.currency.strip() or not self.evidence_reference.strip():
            raise ValueError("financial commitment requires purpose, currency, and evidence")
        if self.amount < 0:
            raise ValueError("financial commitment amount cannot be negative")


@dataclass(frozen=True, slots=True)
class DisbursementAuthorization:
    disbursement_id: SETCIdentifier
    account_id: SETCIdentifier
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    amount: Decimal
    currency: str
    purpose: str
    state: DisbursementState = DisbursementState.REQUESTED
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("disbursement requester cannot self-approve")
        if self.amount <= 0:
            raise ValueError("disbursement amount must be positive")
        if not self.currency.strip() or not self.purpose.strip():
            raise ValueError("disbursement requires currency and purpose")
        if self.state in {DisbursementState.APPROVED, DisbursementState.RELEASED} and (
            self.evidence_reference is None or not self.evidence_reference.strip()
        ):
            raise ValueError("approved or released disbursement requires evidence")


@dataclass(frozen=True, slots=True)
class ReconciliationRecord:
    reconciliation_id: SETCIdentifier
    account_id: SETCIdentifier
    custodian_organization_id: SETCIdentifier
    reconciling_organization_id: SETCIdentifier
    period_reference: str
    reconciled_balance: Decimal
    currency: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.custodian_organization_id == self.reconciling_organization_id:
            raise ValueError("account custodian cannot perform independent reconciliation")
        if not self.period_reference.strip() or not self.currency.strip() or not self.evidence_reference.strip():
            raise ValueError("reconciliation requires period, currency, and evidence")
