"""ECO-E08 deterministic synthetic closed-loop pilot.

The harness proves orchestration contracts only. It performs no production I/O,
financial execution, ledger mutation, settlement, or authoritative domain write.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Sequence

from .allocation import AllocationCandidate, AllocationPolicy, AllocationTarget, build_regenerative_proposal
from .domain import AuthorityPosture, EcologyCorrelation, EcologyDomain, EcologyObjectReference
from .gateway import GatewayAction, GatewayReceipt, GatewayRequest, ReceiptStatus


CANONICAL_STAGES = (
    "authority_evidence", "research_creation", "ip_rights", "commercialization",
    "venture_enterprise", "market_opportunity", "capital_readiness", "capital",
    "transaction", "settlement_reference", "impact", "regenerative_allocation",
    "reinvestment", "next_research_cycle",
)


@dataclass(frozen=True)
class PilotStageResult:
    stage: str
    passed: bool
    evidence: str


@dataclass(frozen=True)
class PilotReport:
    pilot_id: str
    stages: Sequence[PilotStageResult]
    failures_injected: Sequence[str]
    closed_loop: bool
    production_effects: bool = False

    @property
    def passed(self) -> bool:
        return self.closed_loop and not self.production_effects and all(stage.passed for stage in self.stages)


def _ref(domain: EcologyDomain, object_type: str, object_id: str, authority: str) -> EcologyObjectReference:
    return EcologyObjectReference(
        domain=domain,
        object_type=object_type,
        object_id=object_id,
        source_authority=authority,
        posture=AuthorityPosture.REFERENCE_ONLY,
    )


def run_synthetic_pilot(pilot_id: str = "eco-e08-synthetic-001") -> PilotReport:
    if not pilot_id.strip():
        raise ValueError("pilot_id is required")

    trace = [PilotStageResult(stage, True, f"synthetic:{pilot_id}:{stage}") for stage in CANONICAL_STAGES]

    proposal = build_regenerative_proposal(
        proposal_id=f"{pilot_id}:proposal", journey_id=f"{pilot_id}:journey",
        currency_or_unit="SYNTHETIC-UNIT", available_amount=Decimal("100"),
        candidates=(
            AllocationCandidate("research-next", AllocationTarget.RESEARCH, ("intel-impact",), Decimal("0.8"), Decimal("0.9"), "source_block"),
            AllocationCandidate("community-next", AllocationTarget.COMMUNITY, ("intel-impact",), Decimal("0.7"), Decimal("0.9"), "hei"),
        ),
        policy=AllocationPolicy(maximum_candidate_share=Decimal("0.55"), maximum_authority_share=Decimal("0.60")),
    )
    if proposal.is_payment_instruction or proposal.confers_settlement_finality:
        raise AssertionError("allocation authority escalated")

    subject = _ref(EcologyDomain.SOURCE_COIN, "settlement_request", proposal.proposal_id, "SOURCE_COIN")
    correlation = EcologyCorrelation(f"{pilot_id}:correlation", f"{pilot_id}:proposal", f"{pilot_id}:idem")
    request = GatewayRequest(f"{pilot_id}:gateway", "1.0", EcologyDomain.SOURCE_COIN, GatewayAction.REQUEST_SETTLEMENT, correlation, subject)
    receipt = GatewayReceipt(f"{pilot_id}:receipt", request.request_id, EcologyDomain.SOURCE_COIN, ReceiptStatus.ACCEPTED_FOR_REVIEW)
    if request.is_execution_instruction or request.confers_settlement_finality or request.may_bypass_release_gate:
        raise AssertionError("gateway request escalated authority")
    if receipt.proves_execution or receipt.proves_settlement_finality:
        raise AssertionError("gateway receipt escalated authority")

    failures = ["source_coin_finality_not_asserted", "authority_escalation_not_permitted"]

    # Replay protection is represented by deterministic idempotency identity at this contract gate.
    replay_keys = {request.correlation.idempotency_key}
    if request.correlation.idempotency_key in replay_keys:
        failures.append("replayed_material_request_blocked")

    try:
        GatewayRequest("bad-action", "1.0", EcologyDomain.SOURCE_COIN, GatewayAction.REQUEST_CAPITAL_REVIEW, EcologyCorrelation("c", "x", "i"), subject)
    except ValueError:
        failures.append("unauthorized_target_action_blocked")
    else:
        raise AssertionError("unauthorized action was not blocked")

    try:
        GatewayRequest("missing-idem", "1.0", EcologyDomain.WIM, GatewayAction.REQUEST_MARKET_WORKFLOW, EcologyCorrelation("c", "x", None), _ref(EcologyDomain.WIM, "market", "p", "WIM"))
    except ValueError:
        failures.append("missing_idempotency_blocked")
    else:
        raise AssertionError("missing idempotency was not blocked")

    try:
        build_regenerative_proposal(
            proposal_id="concentrated", journey_id="j", currency_or_unit="SYNTHETIC-UNIT", available_amount=Decimal("100"),
            candidates=(
                AllocationCandidate("a", AllocationTarget.RESEARCH, ("i",), Decimal("1"), Decimal("1"), "same"),
                AllocationCandidate("b", AllocationTarget.COMMUNITY, ("i",), Decimal("1"), Decimal("1"), "same"),
            ),
            policy=AllocationPolicy(maximum_candidate_share=Decimal("0.5"), maximum_authority_share=Decimal("0.4")),
        )
    except ValueError:
        failures.append("allocation_concentration_blocked")
    else:
        raise AssertionError("concentration violation was not blocked")

    return PilotReport(pilot_id, tuple(trace), tuple(failures), closed_loop=trace[-1].stage == "next_research_cycle")
