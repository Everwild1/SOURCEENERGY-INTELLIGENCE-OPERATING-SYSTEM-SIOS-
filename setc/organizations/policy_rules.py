"""Institutional policy and rule-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import IntEnum, StrEnum

from setc.core import SETCIdentifier


class PolicyState(StrEnum):
    DRAFT = "DRAFT"
    APPROVED = "APPROVED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    SUPERSEDED = "SUPERSEDED"
    RETIRED = "RETIRED"


class RuleEffect(StrEnum):
    REQUIRE = "REQUIRE"
    PROHIBIT = "PROHIBIT"
    PERMIT = "PERMIT"
    CONDITION = "CONDITION"


class PrecedenceLevel(IntEnum):
    LOCAL = 10
    PROGRAM = 20
    ORGANIZATION = 30
    ECOSYSTEM = 40
    REGULATORY = 50


@dataclass(frozen=True, slots=True)
class InstitutionalPolicy:
    policy_id: SETCIdentifier
    organization_id: SETCIdentifier
    name: str
    version: str
    policy_reference: str
    state: PolicyState = PolicyState.DRAFT
    effective_from: datetime | None = None
    effective_until: datetime | None = None
    supersedes_policy_id: SETCIdentifier | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip() or not self.policy_reference.strip():
            raise ValueError("institutional policy requires name, version, and reference")
        if self.supersedes_policy_id == self.policy_id:
            raise ValueError("policy cannot supersede itself")
        if self.effective_from and self.effective_until and self.effective_until <= self.effective_from:
            raise ValueError("policy effective end must follow start")
        if self.state in {PolicyState.APPROVED, PolicyState.ACTIVE} and not self.evidence_references:
            raise ValueError("approved or active policy requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("policy evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class PolicyRule:
    rule_id: SETCIdentifier
    policy_id: SETCIdentifier
    name: str
    rule_reference: str
    applicability_scope: str
    effect: RuleEffect
    precedence: PrecedenceLevel
    condition_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.rule_reference.strip() or not self.applicability_scope.strip():
            raise ValueError("policy rule requires name, reference, and applicability scope")
        if self.condition_reference is not None and not self.condition_reference.strip():
            raise ValueError("condition_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class PolicyApproval:
    approval_id: SETCIdentifier
    policy_id: SETCIdentifier
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    authority_reference: str
    evidence_reference: str
    approved_at: datetime

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("policy requester cannot self-approve")
        if not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("policy approval requires authority and evidence")


@dataclass(frozen=True, slots=True)
class PolicyException:
    exception_id: SETCIdentifier
    policy_id: SETCIdentifier
    rule_id: SETCIdentifier | None
    subject_reference: str
    rationale: str
    approving_organization_id: SETCIdentifier
    authority_reference: str
    evidence_reference: str
    valid_from: datetime | None = None
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.rationale.strip():
            raise ValueError("policy exception requires subject and rationale")
        if not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("policy exception requires authority and evidence")
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("policy exception validity end must follow start")


@dataclass(frozen=True, slots=True)
class RuleEvaluation:
    evaluation_id: SETCIdentifier
    rule_id: SETCIdentifier
    subject_reference: str
    evaluating_organization_id: SETCIdentifier
    applicable: bool
    satisfied: bool | None
    evaluated_at: datetime
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.subject_reference.strip():
            raise ValueError("rule evaluation subject cannot be blank")
        if self.applicable and self.satisfied is not None and not self.evidence_references:
            raise ValueError("material rule evaluation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("rule evaluation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class PolicyEnforcementRecord:
    enforcement_id: SETCIdentifier
    rule_id: SETCIdentifier
    subject_reference: str
    enforcing_organization_id: SETCIdentifier
    action: str
    evidence_reference: str
    enforced_at: datetime

    def __post_init__(self) -> None:
        if not self.subject_reference.strip() or not self.action.strip() or not self.evidence_reference.strip():
            raise ValueError("policy enforcement requires subject, action, and evidence")


@dataclass(frozen=True, slots=True)
class PolicyDecisionLink:
    link_id: SETCIdentifier
    policy_id: SETCIdentifier
    decision_id: SETCIdentifier
    rationale: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.rationale.strip() or not self.evidence_reference.strip():
            raise ValueError("policy-decision link requires rationale and evidence")
