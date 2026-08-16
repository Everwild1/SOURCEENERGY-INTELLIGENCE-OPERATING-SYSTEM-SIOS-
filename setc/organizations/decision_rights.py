"""Institutional decision-rights and delegation governance for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from setc.core import SETCIdentifier


class DecisionRightState(StrEnum):
    PROPOSED = "PROPOSED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"
    EXPIRED = "EXPIRED"


class DecisionOutcome(StrEnum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    ESCALATED = "ESCALATED"
    WITHDRAWN = "WITHDRAWN"


@dataclass(frozen=True, slots=True)
class DecisionRightAssignment:
    assignment_id: SETCIdentifier
    organization_id: SETCIdentifier
    authorized_organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    state: DecisionRightState = DecisionRightState.PROPOSED
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.authority_reference.strip():
            raise ValueError("decision-right assignment requires scope and authority")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("decision-right validity end must follow start")


@dataclass(frozen=True, slots=True)
class DecisionDelegation:
    delegation_id: SETCIdentifier
    parent_assignment_id: SETCIdentifier
    delegating_organization_id: SETCIdentifier
    delegate_organization_id: SETCIdentifier
    delegated_scope: str
    authority_reference: str
    evidence_reference: str
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if self.delegating_organization_id == self.delegate_organization_id:
            raise ValueError("decision delegation requires distinct organizations")
        if not self.delegated_scope.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("decision delegation requires scope, authority, and evidence")


@dataclass(frozen=True, slots=True)
class ApprovalThreshold:
    threshold_id: SETCIdentifier
    scope: str
    currency: str
    amount: Decimal
    required_approvals: int

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.currency.strip():
            raise ValueError("approval threshold requires scope and currency")
        if self.amount < 0:
            raise ValueError("approval threshold amount cannot be negative")
        if self.required_approvals <= 0:
            raise ValueError("required approvals must be positive")


@dataclass(frozen=True, slots=True)
class QuorumRequirement:
    quorum_id: SETCIdentifier
    scope: str
    eligible_member_count: int
    required_member_count: int

    def __post_init__(self) -> None:
        if not self.scope.strip():
            raise ValueError("quorum scope cannot be blank")
        if self.eligible_member_count <= 0:
            raise ValueError("eligible member count must be positive")
        if self.required_member_count <= 0 or self.required_member_count > self.eligible_member_count:
            raise ValueError("required member count must be within eligible membership")


@dataclass(frozen=True, slots=True)
class DecisionRecusal:
    recusal_id: SETCIdentifier
    decision_reference: str
    organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.decision_reference.strip() or not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("decision recusal requires decision, reason, and evidence")


@dataclass(frozen=True, slots=True)
class DecisionRecord:
    decision_id: SETCIdentifier
    scope: str
    subject_reference: str
    deciding_organization_id: SETCIdentifier
    outcome: DecisionOutcome
    decided_at: datetime | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.scope.strip() or not self.subject_reference.strip():
            raise ValueError("decision record requires scope and subject")
        if self.outcome in {DecisionOutcome.APPROVED, DecisionOutcome.REJECTED} and not self.evidence_references:
            raise ValueError("final decision outcome requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("decision evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class DecisionEscalation:
    escalation_id: SETCIdentifier
    decision_id: SETCIdentifier
    from_organization_id: SETCIdentifier
    to_organization_id: SETCIdentifier
    reason: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.from_organization_id == self.to_organization_id:
            raise ValueError("decision escalation requires distinct organizations")
        if not self.reason.strip() or not self.evidence_reference.strip():
            raise ValueError("decision escalation requires reason and evidence")


@dataclass(frozen=True, slots=True)
class DecisionExecutionRecord:
    execution_id: SETCIdentifier
    decision_id: SETCIdentifier
    executing_organization_id: SETCIdentifier
    action: str
    executed_at: datetime
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.action.strip() or not self.evidence_reference.strip():
            raise ValueError("decision execution requires action and evidence")
