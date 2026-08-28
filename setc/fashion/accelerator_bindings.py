"""WF-DB-003 bindings to existing authoritative accelerator/evidence domains.

This module is deliberately read/validate oriented. It does not create a second
program, identity, rights, market, capital, audit, or Wealth Ecology authority.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Protocol, Sequence
from uuid import UUID

from .accelerator import FashionAcceleratorState, ParticipantBinding, TransitionRequest
from .service import FashionContractError


@dataclass(frozen=True, slots=True)
class AuthorityReference:
    domain: str
    resource: str
    reference: str
    verified: bool


class AcceleratorAuthorityReader(Protocol):
    def enrollment_exists(self, enrollment_id: UUID) -> bool: ...
    def cohort_exists(self, cohort_id: UUID) -> bool: ...
    def evidence(self, reference: str) -> AuthorityReference | None: ...


STATE_AUTHORITIES: Mapping[FashionAcceleratorState, frozenset[tuple[str, str]]] = {
    FashionAcceleratorState.REGISTER: frozenset({("rw", "enrollments"), ("rw", "cohorts")}),
    FashionAcceleratorState.ASSESS: frozenset({("rw", "evidence"), ("public", "seg_evidence_items")}),
    FashionAcceleratorState.PROTECT: frozenset({("seae", "rights_interests"), ("seae", "licenses"), ("seae", "consent_records"), ("public", "seg_evidence_items")}),
    FashionAcceleratorState.DESIGN: frozenset({("fashion", "designs"), ("cruds", "works"), ("seae", "work_registry")}),
    FashionAcceleratorState.VALIDATE: frozenset({("rw", "evidence"), ("public", "seg_evidence_items")}),
    FashionAcceleratorState.PRODUCE: frozenset({("fashion", "production_orders"), ("seae", "productions"), ("gsc", "supply_nodes")}),
    FashionAcceleratorState.CERTIFY: frozenset({("public", "seg_evidence_items"), ("rw", "evidence")}),
    FashionAcceleratorState.MARKET: frozenset({("cruds", "market_access_requests"), ("wim", "opportunities")}),
    FashionAcceleratorState.TRADE: frozenset({("wim", "transactions"), ("rgl", "shipments")}),
    FashionAcceleratorState.CAPITALIZE: frozenset({("rw", "capital_readiness_profiles"), ("rw", "capital_requests"), ("rw", "capital_referrals")}),
    FashionAcceleratorState.SCALE: frozenset({("rw", "replication_evidence"), ("rw", "commercialization_cases")}),
    FashionAcceleratorState.MEASURE: frozenset({("rw", "wealth_yield_records"), ("seae", "wealth_ecology_impact_links"), ("rw", "impact_observations")}),
    FashionAcceleratorState.REINVEST: frozenset({("rw", "wealth_yield_records"), ("rw", "replication_evidence")}),
}


class FashionAcceleratorBindingValidator:
    def __init__(self, authorities: AcceleratorAuthorityReader) -> None:
        self._authorities = authorities

    def validate_enrollment(self, participant: ParticipantBinding, *, enrollment_id: UUID, cohort_id: UUID) -> None:
        participant.validate()
        if not self._authorities.enrollment_exists(enrollment_id):
            raise FashionContractError("Authoritative RW enrollment was not found")
        if not self._authorities.cohort_exists(cohort_id):
            raise FashionContractError("Authoritative RW cohort was not found")

    def validate_transition_evidence(self, request: TransitionRequest) -> tuple[AuthorityReference, ...]:
        allowed = STATE_AUTHORITIES.get(request.requested_state)
        if allowed is None:
            # Discover is the intake state and has no forward gate authority of its own.
            raise FashionContractError("Requested accelerator state has no evidence authority contract")
        resolved: list[AuthorityReference] = []
        for reference in request.evidence_references:
            evidence = self._authorities.evidence(reference)
            if evidence is None:
                raise FashionContractError(f"Evidence reference did not resolve: {reference}")
            if (evidence.domain, evidence.resource) not in allowed:
                raise FashionContractError(
                    f"Evidence authority {evidence.domain}.{evidence.resource} is not valid for {request.requested_state.value}"
                )
            if not evidence.verified:
                raise FashionContractError(f"Evidence reference is not verified: {reference}")
            resolved.append(evidence)
        if not resolved:
            raise FashionContractError("Accelerator transition requires resolved authoritative evidence")
        return tuple(resolved)

    def validate_equivalency(self, request: TransitionRequest) -> None:
        for state, references in (request.equivalency_evidence or {}).items():
            allowed = STATE_AUTHORITIES.get(state)
            if not allowed:
                raise FashionContractError(f"No equivalency authority contract for {state.value}")
            for reference in references:
                evidence = self._authorities.evidence(reference)
                if evidence is None or not evidence.verified or (evidence.domain, evidence.resource) not in allowed:
                    raise FashionContractError(f"Invalid equivalency evidence for {state.value}: {reference}")
