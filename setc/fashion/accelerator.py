"""Evidence-gated M1 Fashion accelerator state contracts."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Mapping, Sequence
from uuid import UUID

from .service import FashionContractError, FashionRequestContext


class FashionAcceleratorState(StrEnum):
    DISCOVER = "discover"
    REGISTER = "register"
    ASSESS = "assess"
    PROTECT = "protect"
    DESIGN = "design"
    VALIDATE = "validate"
    PRODUCE = "produce"
    CERTIFY = "certify"
    MARKET = "market"
    TRADE = "trade"
    CAPITALIZE = "capitalize"
    SCALE = "scale"
    MEASURE = "measure"
    REINVEST = "reinvest"


ORDER = tuple(FashionAcceleratorState)


class TransitionOutcome(StrEnum):
    APPROVED = "approved"
    REMEDIATION_REQUIRED = "remediation_required"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"


@dataclass(frozen=True, slots=True)
class ParticipantBinding:
    creator_id: UUID | None = None
    organization_oid: str | None = None
    fashion_brand_id: UUID | None = None

    def validate(self) -> None:
        if not (self.creator_id or self.organization_oid or self.fashion_brand_id):
            raise FashionContractError("Accelerator enrollment requires an authoritative participant reference")


@dataclass(frozen=True, slots=True)
class TransitionRequest:
    current_state: FashionAcceleratorState
    requested_state: FashionAcceleratorState
    evidence_references: tuple[str, ...]
    equivalency_evidence: Mapping[FashionAcceleratorState, Sequence[str]] | None = None


@dataclass(frozen=True, slots=True)
class TransitionDecision:
    outcome: TransitionOutcome
    resulting_state: FashionAcceleratorState
    reviewer_subject: str
    request_id: UUID
    rationale: str | None = None


class FashionAccelerator:
    """Pure transition engine; persistence and external evidence verification stay outside."""

    @staticmethod
    def evaluate(
        context: FashionRequestContext,
        participant: ParticipantBinding,
        request: TransitionRequest,
        *,
        outcome: TransitionOutcome,
        rationale: str | None = None,
    ) -> TransitionDecision:
        participant.validate()
        FashionAccelerator._validate_transition(request)
        if outcome in {TransitionOutcome.REMEDIATION_REQUIRED, TransitionOutcome.REJECTED} and not rationale:
            raise FashionContractError("Remediation and rejection decisions require rationale")
        resulting = request.requested_state if outcome is TransitionOutcome.APPROVED else request.current_state
        return TransitionDecision(
            outcome=outcome,
            resulting_state=resulting,
            reviewer_subject=context.subject,
            request_id=context.request_id,
            rationale=rationale,
        )

    @staticmethod
    def _validate_transition(request: TransitionRequest) -> None:
        current_index = ORDER.index(request.current_state)
        requested_index = ORDER.index(request.requested_state)
        if requested_index <= current_index:
            raise FashionContractError("Accelerator transitions must advance state")
        if not request.evidence_references:
            raise FashionContractError("Accelerator transition requires evidence references")
        if requested_index == current_index + 1:
            return
        equivalency = request.equivalency_evidence or {}
        bypassed = ORDER[current_index + 1 : requested_index]
        missing = [state.value for state in bypassed if not equivalency.get(state)]
        if missing:
            raise FashionContractError("Skipped accelerator states require equivalency evidence: " + ", ".join(missing))
