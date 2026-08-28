"""WF-DB-004 authoritative technology and manufacturing bindings."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

from .industry40 import FashionTechnologyBinding, RightsState
from .service import FashionContractError


@dataclass(frozen=True, slots=True)
class RegisteredTechnology:
    technology_reference: str
    owning_organization_oid: str | None
    status: str
    evidence_level: int | None


@dataclass(frozen=True, slots=True)
class VerifiedEvidence:
    evidence_reference: str
    verification_state: str


class Industry40AuthorityReader(Protocol):
    def technology(self, technology_reference: str) -> RegisteredTechnology | None: ...
    def evidence(self, evidence_reference: str) -> VerifiedEvidence | None: ...
    def fashion_object_exists(self, resource: str, object_id: UUID) -> bool: ...
    def supply_node_verified(self, supply_node_id: UUID) -> bool: ...
    def seae_production_exists(self, production_id: UUID) -> bool: ...
    def rgl_shipment_exists(self, shipment_id: UUID) -> bool: ...


class FashionIndustry40BindingValidator:
    """Resolve a Fashion technology binding without duplicating external authority."""

    def __init__(self, authorities: Industry40AuthorityReader) -> None:
        self._authorities = authorities

    def validate(self, binding: FashionTechnologyBinding) -> None:
        binding.validate()
        registered = self._authorities.technology(binding.technology.technology_reference)
        if registered is None:
            raise FashionContractError("Technology reference is not registered in the authoritative technology registry")
        if registered.status.lower() not in {"active", "registered", "candidate", "evidence_candidate"}:
            raise FashionContractError("Technology registry record is not in an admissible state")
        implementation = self._authorities.evidence(binding.evidence_reference or "")
        if implementation is None or implementation.verification_state.lower() != "verified":
            raise FashionContractError("Industry 4.0 implementation evidence must be verified")
        if binding.technology.rights_state in {RightsState.REVIEWED, RightsState.LICENSED, RightsState.OWNED}:
            rights = self._authorities.evidence(binding.technology.rights_evidence_reference or "")
            if rights is None or rights.verification_state.lower() != "verified":
                raise FashionContractError("Technology rights status requires verified rights evidence")
        for resource, object_id in self._fashion_targets(binding):
            if not self._authorities.fashion_object_exists(resource, object_id):
                raise FashionContractError(f"Fashion target does not exist: {resource}:{object_id}")

    def validate_manufacturing_chain(
        self,
        *,
        production_order_id: UUID,
        supply_node_id: UUID,
        seae_production_id: UUID | None = None,
        shipment_id: UUID | None = None,
    ) -> None:
        if not self._authorities.fashion_object_exists("production_orders", production_order_id):
            raise FashionContractError("Fashion production order was not found")
        if not self._authorities.supply_node_verified(supply_node_id):
            raise FashionContractError("Manufacturing supply node must be verified by GSC authority")
        if seae_production_id and not self._authorities.seae_production_exists(seae_production_id):
            raise FashionContractError("Referenced SEAE production was not found")
        if shipment_id and not self._authorities.rgl_shipment_exists(shipment_id):
            raise FashionContractError("Referenced RGL shipment was not found")

    @staticmethod
    def _fashion_targets(binding: FashionTechnologyBinding) -> tuple[tuple[str, UUID], ...]:
        candidates = (
            ("designs", binding.design_id),
            ("product_models", binding.product_model_id),
            ("production_orders", binding.production_order_id),
            ("production_batches", binding.production_batch_id),
            ("materials", binding.material_id),
        )
        return tuple((resource, object_id) for resource, object_id in candidates if object_id is not None)
