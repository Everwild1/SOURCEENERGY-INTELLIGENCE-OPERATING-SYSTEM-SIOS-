"""SC-E06 contribution validation and governed reward primitives."""

from dataclasses import dataclass
from enum import Enum
from uuid import UUID

from setc.core import SETCIdentifier

from .compliance import ComplianceDecision


class ContributionStatus(str, Enum):
    SUBMITTED = "SUBMITTED"
    VALIDATED = "VALIDATED"
    REJECTED = "REJECTED"


class RewardStatus(str, Enum):
    PROPOSED = "PROPOSED"
    APPROVED = "APPROVED"
    EXECUTED = "EXECUTED"
    REJECTED = "REJECTED"


@dataclass(frozen=True)
class ContributionRecord:
    contribution_id: UUID
    contributor_organization_id: SETCIdentifier
    evidence_ref: str
    validator_ref: str
    contributor_principal_ref: str
    status: ContributionStatus = ContributionStatus.SUBMITTED

    def __post_init__(self) -> None:
        if not self.evidence_ref.strip() or not self.validator_ref.strip():
            raise ValueError("evidence_ref and validator_ref are required")
        if self.validator_ref == self.contributor_principal_ref:
            raise ValueError("self-validation is prohibited")


@dataclass(frozen=True)
class RewardPolicy:
    reward_policy_id: UUID
    version: str
    max_reward_minor: int
    active: bool = True

    def __post_init__(self) -> None:
        if not self.version.strip():
            raise ValueError("version is required")
        if self.max_reward_minor <= 0:
            raise ValueError("max_reward_minor must be positive")


@dataclass(frozen=True)
class RewardGrant:
    reward_grant_id: UUID
    contribution_id: UUID
    recipient_organization_id: SETCIdentifier
    recipient_account_id: UUID
    reward_policy: RewardPolicy
    amount_minor: int
    funding_account_id: UUID
    compliance_decision: ComplianceDecision
    authorization_ref: str
    status: RewardStatus = RewardStatus.PROPOSED

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("amount_minor must be positive")
        if self.amount_minor > self.reward_policy.max_reward_minor:
            raise ValueError("reward exceeds policy maximum")
        if self.funding_account_id == self.recipient_account_id:
            raise ValueError("funding and recipient accounts must differ")
        if not self.authorization_ref.strip():
            raise ValueError("authorization_ref is required")

    def can_execute(self, contribution: ContributionRecord) -> bool:
        return (
            contribution.contribution_id == self.contribution_id
            and contribution.status is ContributionStatus.VALIDATED
            and self.reward_policy.active
            and self.compliance_decision.permits_execution()
            and self.status is RewardStatus.APPROVED
        )
