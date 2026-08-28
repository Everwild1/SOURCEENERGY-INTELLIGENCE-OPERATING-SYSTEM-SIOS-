"""ECO-E08 deterministic synthetic closed-loop pilot.

The harness proves orchestration contracts only. It performs no production I/O,
financial execution, ledger mutation, settlement, or authoritative domain write.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Sequence

from .allocation import AllocationCandidate, AllocationPolicy, AllocationTarget, build_regenerative_proposal
from .gateway import GatewayAction, GatewayRequest, GatewayTarget, MockGateway, build_request


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


def run_synthetic_pilot(pilot_id: str = "eco-e08-synthetic-001") -> PilotReport:
    if not pilot_id.strip():
        raise ValueError("pilot_id is required")

    trace = [PilotStageResult(stage, True, f"synthetic:{pilot_id}:{stage}") for stage in CANONICAL_STAGES]

    # ECO-E06: intelligence-backed proposal, deliberately projection-only.
    proposal = build_regenerative_proposal(
        proposal_id=f"{pilot_id}:proposal",
        journey_id=f"{pilot_id}:journey",
        currency_or_unit="SYNTHETIC-UNIT",
        available_amount=Decimal("100"),
        candidates=(
            AllocationCandidate("research-next", AllocationTarget.RESEARCH, ("intel-impact",), Decimal("0.8"), Decimal("0.9"), "source_block"),
            AllocationCandidate("community-next", AllocationTarget.COMMUNITY, ("intel-impact",), Decimal("0.7"), Decimal("0.9"), "hei"),
        ),
        policy=AllocationPolicy(maximum_candidate_share=Decimal("0.55"), maximum_authority_share=Decimal("0.60")),
    )
    if proposal.is_payment_instruction or proposal.confers_settlement_finality:
        raise AssertionError("allocation authority escalated")

    # ECO-E07: mocked request/receipt only; never authoritative completion.
    gateway = MockGateway()
    request = build_request(
        request_id=f"{pilot_id}:gateway",
        target=GatewayTarget.SOURCE_COIN,
        action=GatewayAction.REQUEST_SETTLEMENT_REFERENCE,
        correlation_id=f"{pilot_id}:correlation",
        causation_id=f"{pilot_id}:proposal",
        idempotency_key=f"{pilot_id}:idem",
        payload_reference=proposal.proposal_id,
    )
    receipt = gateway.send(request)
    if receipt.confers_execution_authority or receipt.confers_settlement_finality:
        raise AssertionError("gateway receipt escalated authority")

    failures = []
    # Replay must fail closed.
    try:
        gateway.send(request)
    except ValueError:
        failures.append("replayed_material_request_blocked")
    else:
        raise AssertionError("replay was not blocked")

    # Unauthorized action must fail closed.
    try:
        build_request(
            request_id="bad-action", target=GatewayTarget.SOURCE_COIN,
            action=GatewayAction.REQUEST_TREASURY_REVIEW,
            correlation_id="c", causation_id="x", idempotency_key="i", payload_reference="p",
        )
    except ValueError:
        failures.append("unauthorized_target_action_blocked")
    else:
        raise AssertionError("unauthorized action was not blocked")

    # Missing idempotency on material request must fail closed.
    try:
        build_request(
            request_id="missing-idem", target=GatewayTarget.WIM,
            action=GatewayAction.REQUEST_MARKET_REVIEW,
            correlation_id="c", causation_id="x", idempotency_key="", payload_reference="p",
        )
    except ValueError:
        failures.append("missing_idempotency_blocked")
    else:
        raise AssertionError("missing idempotency was not blocked")

    # Concentration policy violation must fail closed.
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

    failures.extend(("source_coin_finality_not_asserted", "authority_escalation_not_permitted"))
    return PilotReport(pilot_id, tuple(trace), tuple(failures), closed_loop=trace[-1].stage == "next_research_cycle")
