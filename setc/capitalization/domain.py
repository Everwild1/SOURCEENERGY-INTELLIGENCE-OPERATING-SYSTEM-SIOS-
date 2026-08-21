"""Governance invariants for the SourceEnergy Capitalization Block.

The domain objects in this module model software and data controls. They do not
create a banking relationship, custody authority, regulatory permission,
capital commitment, or settlement finality.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum


class RelationshipState(StrEnum):
    TARGET = "TARGET"
    IDENTIFIED = "IDENTIFIED"
    CONTACTED = "CONTACTED"
    DUE_DILIGENCE = "DUE_DILIGENCE"
    QUALIFIED = "QUALIFIED"
    AGREEMENT_PENDING = "AGREEMENT_PENDING"
    CONTRACTED = "CONTRACTED"
    INTEGRATION_PENDING = "INTEGRATION_PENDING"
    INTEGRATED = "INTEGRATED"
    LIVE = "LIVE"
    SUSPENDED = "SUSPENDED"
    TERMINATED = "TERMINATED"


class ConnectivityStatus(StrEnum):
    NOT_CONNECTED = "NOT_CONNECTED"
    SANDBOX = "SANDBOX"
    TEST = "TEST"
    CERTIFICATION = "CERTIFICATION"
    PRODUCTION = "PRODUCTION"
    DEGRADED = "DEGRADED"
    OFFLINE = "OFFLINE"


class VerificationStatus(StrEnum):
    UNVERIFIED = "UNVERIFIED"
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    RESTRICTED = "RESTRICTED"
    SUSPENDED = "SUSPENDED"


class SettlementRail(StrEnum):
    FIAT_EXTERNAL = "FIAT_EXTERNAL"
    SOURCE_COIN = "SOURCE_COIN"
    INTERNAL_BOOK_TRANSFER = "INTERNAL_BOOK_TRANSFER"


class SettlementStatus(StrEnum):
    DRAFT = "DRAFT"
    PENDING_APPROVAL = "PENDING_APPROVAL"
    APPROVED = "APPROVED"
    SUBMITTED = "SUBMITTED"
    ACCEPTED = "ACCEPTED"
    SETTLED = "SETTLED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"
    REVERSED = "REVERSED"
    RESTRICTED = "RESTRICTED"
    EXPIRED = "EXPIRED"


_SETTLEMENT_TRANSITIONS: dict[SettlementStatus, frozenset[SettlementStatus]] = {
    SettlementStatus.DRAFT: frozenset(
        {SettlementStatus.PENDING_APPROVAL, SettlementStatus.CANCELLED}
    ),
    SettlementStatus.PENDING_APPROVAL: frozenset(
        {
            SettlementStatus.APPROVED,
            SettlementStatus.RESTRICTED,
            SettlementStatus.CANCELLED,
        }
    ),
    SettlementStatus.APPROVED: frozenset(
        {
            SettlementStatus.SUBMITTED,
            SettlementStatus.CANCELLED,
            SettlementStatus.EXPIRED,
        }
    ),
    SettlementStatus.SUBMITTED: frozenset(
        {
            SettlementStatus.ACCEPTED,
            SettlementStatus.FAILED,
            SettlementStatus.CANCELLED,
        }
    ),
    SettlementStatus.ACCEPTED: frozenset(
        {
            SettlementStatus.SETTLED,
            SettlementStatus.FAILED,
            SettlementStatus.REVERSED,
        }
    ),
    SettlementStatus.SETTLED: frozenset({SettlementStatus.REVERSED}),
    SettlementStatus.RESTRICTED: frozenset(
        {SettlementStatus.PENDING_APPROVAL, SettlementStatus.CANCELLED}
    ),
    SettlementStatus.FAILED: frozenset(),
    SettlementStatus.CANCELLED: frozenset(),
    SettlementStatus.REVERSED: frozenset(),
    SettlementStatus.EXPIRED: frozenset(),
}


def assert_settlement_transition(
    prior: SettlementStatus, new: SettlementStatus
) -> None:
    """Reject status changes outside the governed lifecycle."""

    if new == prior:
        return
    if new not in _SETTLEMENT_TRANSITIONS[prior]:
        raise ValueError(f"invalid settlement transition: {prior} -> {new}")


def _required_text(value: str, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _currency(value: str) -> str:
    normalized = value.strip().upper()
    if len(normalized) != 3 or not normalized.isalpha():
        raise ValueError("currency must be a three-letter alphabetic code")
    return normalized


@dataclass(frozen=True, slots=True)
class InstitutionStatus:
    relationship_state: RelationshipState
    connectivity_status: ConnectivityStatus
    verification_status: VerificationStatus
    evidence_reference: str | None = None
    last_verified_at: str | None = None

    def __post_init__(self) -> None:
        evidence = self.evidence_reference.strip() if self.evidence_reference else None
        verified_at = self.last_verified_at.strip() if self.last_verified_at else None

        evidence_required = {
            RelationshipState.CONTRACTED,
            RelationshipState.INTEGRATION_PENDING,
            RelationshipState.INTEGRATED,
            RelationshipState.LIVE,
        }
        if self.relationship_state in evidence_required and not evidence:
            raise ValueError(
                "contracted or integrated relationship states require evidence"
            )

        if self.relationship_state is RelationshipState.LIVE:
            if self.connectivity_status is not ConnectivityStatus.PRODUCTION:
                raise ValueError("LIVE institutions require PRODUCTION connectivity")
            if self.verification_status is not VerificationStatus.VERIFIED:
                raise ValueError("LIVE institutions require VERIFIED status")
            if not verified_at:
                raise ValueError("LIVE institutions require a verification timestamp")

        object.__setattr__(self, "evidence_reference", evidence)
        object.__setattr__(self, "last_verified_at", verified_at)

    @property
    def public_label(self) -> str:
        if self.relationship_state is RelationshipState.LIVE:
            return "Verified live connection"
        if self.relationship_state in {
            RelationshipState.CONTRACTED,
            RelationshipState.INTEGRATION_PENDING,
            RelationshipState.INTEGRATED,
        }:
            return "Evidence-backed relationship; production status not implied"
        return "Registry target; no verified production connection"


@dataclass(frozen=True, slots=True)
class SettlementInstruction:
    instruction_reference: str
    idempotency_key: str
    correlation_id: str
    rail: SettlementRail
    amount: Decimal
    currency: str
    status: SettlementStatus = SettlementStatus.DRAFT
    finality_authority: str | None = None
    confirmation_reference: str | None = None
    settled_at: str | None = None

    def __post_init__(self) -> None:
        instruction_reference = _required_text(
            self.instruction_reference, "instruction_reference"
        )
        idempotency_key = _required_text(self.idempotency_key, "idempotency_key")
        correlation_id = _required_text(self.correlation_id, "correlation_id")
        currency = _currency(self.currency)
        if self.amount <= Decimal("0"):
            raise ValueError("settlement amount must be positive")

        authority = self.finality_authority.strip() if self.finality_authority else None
        confirmation = (
            self.confirmation_reference.strip()
            if self.confirmation_reference
            else None
        )
        settled_at = self.settled_at.strip() if self.settled_at else None

        if self.rail is SettlementRail.SOURCE_COIN and authority not in {
            None,
            "SOURCE_COIN_DOMAIN",
        }:
            raise ValueError(
                "Source Coin settlement finality belongs to SOURCE_COIN_DOMAIN"
            )

        if self.status is SettlementStatus.SETTLED:
            if not authority or not confirmation or not settled_at:
                raise ValueError(
                    "SETTLED requires finality authority, confirmation, and timestamp"
                )
            if self.rail is SettlementRail.SOURCE_COIN and authority != "SOURCE_COIN_DOMAIN":
                raise ValueError(
                    "Source Coin settlement requires SOURCE_COIN_DOMAIN finality"
                )

        object.__setattr__(self, "instruction_reference", instruction_reference)
        object.__setattr__(self, "idempotency_key", idempotency_key)
        object.__setattr__(self, "correlation_id", correlation_id)
        object.__setattr__(self, "currency", currency)
        object.__setattr__(self, "finality_authority", authority)
        object.__setattr__(self, "confirmation_reference", confirmation)
        object.__setattr__(self, "settled_at", settled_at)


@dataclass(frozen=True, slots=True)
class ApprovalAction:
    request_reference: str
    requested_by_actor: str
    actioned_by_actor: str
    decision: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        request_reference = _required_text(
            self.request_reference, "request_reference"
        )
        requested_by = _required_text(
            self.requested_by_actor, "requested_by_actor"
        )
        actioned_by = _required_text(
            self.actioned_by_actor, "actioned_by_actor"
        )
        decision = self.decision.strip().upper()
        if decision not in {"APPROVE", "REJECT", "ABSTAIN"}:
            raise ValueError("unsupported approval decision")
        if requested_by == actioned_by and decision in {"APPROVE", "REJECT"}:
            raise ValueError("requesters cannot approve or reject their own request")

        evidence = self.evidence_reference.strip() if self.evidence_reference else None
        if decision in {"APPROVE", "REJECT"} and not evidence:
            raise ValueError("material approval decisions require evidence")

        object.__setattr__(self, "request_reference", request_reference)
        object.__setattr__(self, "requested_by_actor", requested_by)
        object.__setattr__(self, "actioned_by_actor", actioned_by)
        object.__setattr__(self, "decision", decision)
        object.__setattr__(self, "evidence_reference", evidence)
