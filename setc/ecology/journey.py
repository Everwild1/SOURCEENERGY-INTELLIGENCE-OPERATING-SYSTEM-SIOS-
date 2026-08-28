"""Canonical cross-domain Ecology journey graph.

The graph links source-domain records without transferring their authority. It
models lifecycle coordination and regenerative feedback only.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Iterable

from .domain import EcologyObjectReference


class JourneyStage(StrEnum):
    AUTHORITY_EVIDENCE = "authority_evidence"
    RESEARCH_CREATION = "research_creation"
    IP_RIGHTS = "ip_rights"
    COMMERCIALIZATION = "commercialization"
    VENTURE_ENTERPRISE = "venture_enterprise"
    MARKET_OPPORTUNITY = "market_opportunity"
    CAPITAL_READINESS = "capital_readiness"
    CAPITAL = "capital"
    TRANSACTION = "transaction"
    SETTLEMENT_REFERENCE = "settlement_reference"
    IMPACT = "impact"
    REGENERATIVE_ALLOCATION = "regenerative_allocation"
    REINVESTMENT = "reinvestment"


class LifecycleDimension(StrEnum):
    RESEARCH_IP = "research_ip"
    COMMERCIALIZATION = "commercialization"
    MARKET_READINESS = "market_readiness"
    CAPITAL_READINESS = "capital_readiness"
    REGULATORY = "regulatory"
    DEPLOYMENT = "deployment"
    IMPACT = "impact"


@dataclass(frozen=True, slots=True)
class JourneyState:
    dimension: LifecycleDimension
    state: str
    source: EcologyObjectReference

    def __post_init__(self) -> None:
        state = self.state.strip()
        if not state:
            raise ValueError("journey dimension state is required")
        object.__setattr__(self, "state", state)


@dataclass(frozen=True, slots=True)
class JourneyNode:
    stage: JourneyStage
    reference: EcologyObjectReference
    states: tuple[JourneyState, ...] = ()

    def __post_init__(self) -> None:
        for state in self.states:
            if state.source != self.reference:
                raise ValueError("journey state source must match its node reference")


@dataclass(frozen=True, slots=True)
class JourneyEdge:
    source: JourneyNode
    target: JourneyNode
    relationship: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        relationship = self.relationship.strip()
        if not relationship:
            raise ValueError("journey relationship is required")
        if self.source == self.target:
            raise ValueError("journey edge cannot self-reference")
        object.__setattr__(self, "relationship", relationship)
        if self.evidence_reference is not None:
            evidence = self.evidence_reference.strip()
            if not evidence:
                raise ValueError("evidence reference cannot be blank")
            object.__setattr__(self, "evidence_reference", evidence)

    @property
    def transfers_authority(self) -> bool:
        return False

    @property
    def confers_financial_finality(self) -> bool:
        return False


@dataclass(slots=True)
class EcologyJourney:
    journey_id: str
    nodes: list[JourneyNode] = field(default_factory=list)
    edges: list[JourneyEdge] = field(default_factory=list)

    def __post_init__(self) -> None:
        journey_id = self.journey_id.strip()
        if not journey_id:
            raise ValueError("journey ID is required")
        self.journey_id = journey_id

    def add_node(self, node: JourneyNode) -> None:
        if node in self.nodes:
            raise ValueError("journey node already exists")
        self.nodes.append(node)

    def link(self, edge: JourneyEdge) -> None:
        if edge.source not in self.nodes or edge.target not in self.nodes:
            raise ValueError("both journey edge nodes must already belong to the journey")
        if edge in self.edges:
            raise ValueError("journey edge already exists")
        self.edges.append(edge)

    def stages(self) -> tuple[JourneyStage, ...]:
        return tuple(node.stage for node in self.nodes)

    def references(self) -> tuple[EcologyObjectReference, ...]:
        return tuple(node.reference for node in self.nodes)

    def extend(self, nodes: Iterable[JourneyNode]) -> None:
        for node in nodes:
            self.add_node(node)
