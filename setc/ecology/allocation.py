"""ECO-E06 governed regenerative allocation proposal model.

Ecology may derive recommendations. It never executes payments, mutates ledgers,
or confers treasury, settlement, fiduciary, compliance, ownership, or approval authority.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from enum import Enum
from typing import Mapping, Sequence


class AllocationTarget(str, Enum):
    RESEARCH = "research"
    ENTERPRISE = "enterprise"
    COMMUNITY = "community"
    INFRASTRUCTURE = "infrastructure"
    HUMAN_CAPITAL = "human_capital"
    ECOSYSTEM = "ecosystem"


class ProposalStatus(str, Enum):
    DRAFT = "draft"
    PROPOSED = "proposed"
    REVIEWED = "reviewed"
    EXTERNALLY_AUTHORIZED = "externally_authorized"
    REJECTED = "rejected"
    SUPERSEDED = "superseded"


@dataclass(frozen=True)
class AllocationCandidate:
    reference_id: str
    target: AllocationTarget
    intelligence_result_ids: Sequence[str]
    score: Decimal
    confidence: Decimal
    authority_key: str

    def __post_init__(self) -> None:
        if not self.reference_id.strip() or not self.authority_key.strip():
            raise ValueError("candidate reference and authority are required")
        if not self.intelligence_result_ids:
            raise ValueError("candidate requires ECO-E05 intelligence evidence")
        if not Decimal("0") <= self.score <= Decimal("1"):
            raise ValueError("score must be between 0 and 1")
        if not Decimal("0") <= self.confidence <= Decimal("1"):
            raise ValueError("confidence must be between 0 and 1")


@dataclass(frozen=True)
class AllocationPolicy:
    minimum_confidence: Decimal = Decimal("0.50")
    maximum_candidate_share: Decimal = Decimal("0.40")
    maximum_authority_share: Decimal = Decimal("0.60")
    target_caps: Mapping[AllocationTarget, Decimal] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for value in (self.minimum_confidence, self.maximum_candidate_share, self.maximum_authority_share):
            if not Decimal("0") <= value <= Decimal("1"):
                raise ValueError("policy ratios must be between 0 and 1")
        for cap in self.target_caps.values():
            if not Decimal("0") <= cap <= Decimal("1"):
                raise ValueError("target caps must be between 0 and 1")


@dataclass(frozen=True)
class AllocationLine:
    candidate_reference_id: str
    target: AllocationTarget
    authority_key: str
    proposed_amount: Decimal
    confidence: Decimal
    intelligence_result_ids: Sequence[str]


@dataclass(frozen=True)
class RegenerativeAllocationProposal:
    proposal_id: str
    journey_id: str
    currency_or_unit: str
    available_amount: Decimal
    lines: Sequence[AllocationLine]
    status: ProposalStatus = ProposalStatus.PROPOSED
    external_authority_reference: str | None = None
    supersedes_proposal_id: str | None = None
    rationale: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.proposal_id.strip() or not self.journey_id.strip() or not self.currency_or_unit.strip():
            raise ValueError("proposal identity, journey and unit are required")
        if self.available_amount < 0:
            raise ValueError("available amount cannot be negative")
        if sum((line.proposed_amount for line in self.lines), Decimal("0")) > self.available_amount:
            raise ValueError("proposal cannot allocate more than the available amount")
        if self.status is ProposalStatus.EXTERNALLY_AUTHORIZED and not self.external_authority_reference:
            raise ValueError("external authorization requires an authority reference")
        if self.status is ProposalStatus.SUPERSEDED and not self.supersedes_proposal_id:
            raise ValueError("superseded proposals require lineage")

    @property
    def is_payment_instruction(self) -> bool:
        return False

    @property
    def confers_settlement_finality(self) -> bool:
        return False

    @property
    def confers_ledger_or_treasury_authority(self) -> bool:
        return False

    @property
    def confers_fiduciary_or_compliance_approval(self) -> bool:
        return False


def build_regenerative_proposal(
    *,
    proposal_id: str,
    journey_id: str,
    currency_or_unit: str,
    available_amount: Decimal,
    candidates: Sequence[AllocationCandidate],
    policy: AllocationPolicy,
) -> RegenerativeAllocationProposal:
    """Create a deterministic proposal; never an execution instruction."""
    eligible = [candidate for candidate in candidates if candidate.confidence >= policy.minimum_confidence]
    if available_amount < 0:
        raise ValueError("available amount cannot be negative")
    if not eligible or available_amount == 0:
        return RegenerativeAllocationProposal(proposal_id, journey_id, currency_or_unit, available_amount, ())

    total_weight = sum((c.score * c.confidence for c in eligible), Decimal("0"))
    if total_weight <= 0:
        raise ValueError("eligible candidates require positive aggregate weight")

    provisional: list[AllocationLine] = []
    for candidate in sorted(eligible, key=lambda c: c.reference_id):
        weight = candidate.score * candidate.confidence
        amount = available_amount * weight / total_weight
        amount = min(amount, available_amount * policy.maximum_candidate_share)
        target_cap = policy.target_caps.get(candidate.target)
        if target_cap is not None:
            amount = min(amount, available_amount * target_cap)
        provisional.append(AllocationLine(candidate.reference_id, candidate.target, candidate.authority_key, amount, candidate.confidence, tuple(candidate.intelligence_result_ids)))

    # Fail closed on authority concentration rather than silently redistributing.
    authority_totals: dict[str, Decimal] = {}
    for line in provisional:
        authority_totals[line.authority_key] = authority_totals.get(line.authority_key, Decimal("0")) + line.proposed_amount
    ceiling = available_amount * policy.maximum_authority_share
    if any(amount > ceiling for amount in authority_totals.values()):
        raise ValueError("proposal exceeds authority concentration policy")

    return RegenerativeAllocationProposal(
        proposal_id=proposal_id,
        journey_id=journey_id,
        currency_or_unit=currency_or_unit,
        available_amount=available_amount,
        lines=tuple(provisional),
        rationale={"method": "score_x_confidence_weighted_with_fail_closed_caps", "authority": "ecology_projection_only"},
    )
