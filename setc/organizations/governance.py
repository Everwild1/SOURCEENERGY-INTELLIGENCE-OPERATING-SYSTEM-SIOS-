"""Governance, audit, and institutional-control primitives governed by SETC-120."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class DecisionState(StrEnum):
    PROPOSED = "PROPOSED"
    PENDING_APPROVAL = "PENDING_APPROVAL"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"
    CLOSED = "CLOSED"


class ControlFindingState(StrEnum):
    OPEN = "OPEN"
    REMEDIATION = "REMEDIATION"
    ACCEPTED_RISK = "ACCEPTED_RISK"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class GovernanceAuthority:
    authority_id: SETCIdentifier
    organization_id: SETCIdentifier
    authority_type: str
    scope: str
    policy_reference: str
    effective_from: datetime | None = None
    effective_to: datetime | None = None

    def __post_init__(self) -> None:
        for value, label in (
            (self.authority_type, "authority_type"),
            (self.scope, "scope"),
            (self.policy_reference, "policy_reference"),
        ):
            if not value.strip():
                raise ValueError(f"{label} cannot be blank")
        if self.effective_from and self.effective_to and self.effective_to <= self.effective_from:
            raise ValueError("authority end must follow start")


@dataclass(frozen=True, slots=True)
class GovernedDecision:
    decision_id: SETCIdentifier
    subject_reference: str
    decision_type: str
    requested_by_organization_id: SETCIdentifier
    authority_id: SETCIdentifier
    state: DecisionState = DecisionState.PROPOSED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.decision_type.strip():
            raise ValueError("decision requires subject and type")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("decision evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ApprovalRecord:
    approval_id: SETCIdentifier
    decision_id: SETCIdentifier
    approver_organization_id: SETCIdentifier
    requested_by_organization_id: SETCIdentifier
    approved: bool
    authority_id: SETCIdentifier
    evidence_reference: str
    decided_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.approver_organization_id == self.requested_by_organization_id:
            raise ValueError("requester cannot approve its own governed decision")
        if not self.evidence_reference.strip():
            raise ValueError("approval requires evidence")


@dataclass(frozen=True, slots=True)
class PolicyVersion:
    policy_id: SETCIdentifier
    policy_reference: str
    version: str
    issuing_organization_id: SETCIdentifier
    effective_at: datetime
    supersedes_policy_id: SETCIdentifier | None = None

    def __post_init__(self) -> None:
        if not self.policy_reference.strip() or not self.version.strip():
            raise ValueError("policy reference and version are required")


@dataclass(frozen=True, slots=True)
class AuditEvent:
    audit_event_id: SETCIdentifier
    actor_reference: str
    action: str
    subject_reference: str
    occurred_at: datetime
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        for value, label in (
            (self.actor_reference, "actor_reference"),
            (self.action, "action"),
            (self.subject_reference, "subject_reference"),
        ):
            if not value.strip():
                raise ValueError(f"{label} cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class GovernanceException:
    exception_id: SETCIdentifier
    subject_reference: str
    policy_reference: str
    rationale: str
    approved_by_organization_id: SETCIdentifier
    evidence_reference: str
    expires_at: datetime | None = None

    def __post_init__(self) -> None:
        for value, label in (
            (self.subject_reference, "subject_reference"),
            (self.policy_reference, "policy_reference"),
            (self.rationale, "rationale"),
            (self.evidence_reference, "evidence_reference"),
        ):
            if not value.strip():
                raise ValueError(f"{label} cannot be blank")


@dataclass(frozen=True, slots=True)
class ControlFinding:
    finding_id: SETCIdentifier
    subject_reference: str
    control_reference: str
    finding: str
    state: ControlFindingState = ControlFindingState.OPEN
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.control_reference.strip() or not self.finding.strip():
            raise ValueError("control finding requires subject, control, and finding text")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ControlRemediation:
    remediation_id: SETCIdentifier
    finding_id: SETCIdentifier
    action: str
    owner_organization_id: SETCIdentifier
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("remediation action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
