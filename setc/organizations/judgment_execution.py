"""Institutional judgment and execution-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class JudgmentState(StrEnum):
    ISSUED = "ISSUED"
    FINAL = "FINAL"
    STAYED = "STAYED"
    EXECUTING = "EXECUTING"
    SATISFIED = "SATISFIED"
    CLOSED = "CLOSED"


class ExecutionState(StrEnum):
    ORDERED = "ORDERED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    VERIFIED = "VERIFIED"
    FAILED = "FAILED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class InstitutionalJudgment:
    judgment_id: SETCIdentifier
    determination_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    judgment_reference: str
    rationale: str
    issued_at: datetime
    state: JudgmentState = JudgmentState.ISSUED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.issuing_organization_id:
            raise ValueError("institutional judgment requires an independent issuer")
        if not self.judgment_reference.strip() or not self.rationale.strip():
            raise ValueError("institutional judgment requires reference and rationale")
        if not self.evidence_references:
            raise ValueError("institutional judgment requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("judgment evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class JudgmentFinality:
    finality_id: SETCIdentifier
    judgment_id: SETCIdentifier
    finalizing_organization_id: SETCIdentifier
    final_at: datetime
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("judgment finality requires authority and evidence")


@dataclass(frozen=True, slots=True)
class JudgmentStay:
    stay_id: SETCIdentifier
    judgment_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    reason: str
    authority_reference: str
    evidence_reference: str
    effective_at: datetime
    expires_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.reason.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("judgment stay requires reason, authority, and evidence")
        if self.expires_at is not None and self.expires_at <= self.effective_at:
            raise ValueError("judgment stay expiry must follow effective time")


@dataclass(frozen=True, slots=True)
class ExecutionOrder:
    order_id: SETCIdentifier
    judgment_id: SETCIdentifier
    ordering_organization_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    authority_reference: str
    evidence_reference: str
    due_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.ordering_organization_id == self.responsible_organization_id:
            raise ValueError("execution order requires separation of ordering and responsible organizations")
        if not self.action.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("execution order requires action, authority, and evidence")


@dataclass(frozen=True, slots=True)
class JudgmentExecutionRecord:
    execution_id: SETCIdentifier
    order_id: SETCIdentifier
    executing_organization_id: SETCIdentifier
    state: ExecutionState
    action: str
    recorded_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("judgment execution action cannot be blank")
        if self.state in {ExecutionState.COMPLETED, ExecutionState.VERIFIED, ExecutionState.CLOSED} and not self.evidence_references:
            raise ValueError("material execution state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("execution evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ExecutionVerification:
    verification_id: SETCIdentifier
    execution_id: SETCIdentifier
    executing_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    verified: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.executing_organization_id == self.verifier_organization_id:
            raise ValueError("execution verification requires an independent verifier")
        if self.verified and not self.evidence_references:
            raise ValueError("verified judgment execution requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("verification evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class JudgmentSatisfactionRecord:
    satisfaction_id: SETCIdentifier
    judgment_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    confirming_organization_id: SETCIdentifier
    satisfied_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.confirming_organization_id:
            raise ValueError("judgment satisfaction requires independent confirmation")
        if not self.evidence_references:
            raise ValueError("judgment satisfaction requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("satisfaction evidence references cannot contain blanks")
