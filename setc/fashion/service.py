"""Fail-closed WF-DB-002 service adapter.

This module defines application authorization and repository ports. It deliberately
contains no client credential, settlement, rights-creation, or direct database
connection logic. Infrastructure adapters must implement ``FashionRepository``
server-side and remain subject to the promoted Fashion RLS controls.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any, Mapping, Protocol
from uuid import UUID, uuid4


class FashionRole(StrEnum):
    READER = "fashion_reader"
    EDITOR = "fashion_editor"
    PRODUCTION_OPERATOR = "fashion_production_operator"
    LIFECYCLE_RECORDER = "fashion_lifecycle_recorder"
    EVIDENCE_SUBMITTER = "fashion_evidence_submitter"
    EVIDENCE_VERIFIER = "fashion_evidence_verifier"
    ADMIN = "fashion_admin"


@dataclass(frozen=True, slots=True)
class FashionRequestContext:
    subject: str
    roles: frozenset[FashionRole]
    request_id: UUID = field(default_factory=uuid4)


class FashionAuthorizationError(PermissionError):
    pass


class FashionContractError(ValueError):
    pass


class FashionAuthorization:
    @staticmethod
    def require(context: FashionRequestContext, *allowed: FashionRole) -> None:
        if not context.roles.intersection(allowed):
            raise FashionAuthorizationError("Fashion operation is not authorized")


class FashionRepository(Protocol):
    def get(self, resource: str, resource_id: UUID) -> Mapping[str, Any] | None: ...
    def list(self, resource: str) -> list[Mapping[str, Any]]: ...
    def create(self, resource: str, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]: ...
    def update(self, resource: str, resource_id: UUID, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]: ...
    def append_lifecycle_event(self, product_instance_id: UUID, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]: ...
    def submit_evidence_link(self, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]: ...
    def verify_evidence_link(self, evidence_link_id: UUID, verification_state: str, *, audit: Mapping[str, str]) -> Mapping[str, Any]: ...


class FashionService:
    READABLE = frozenset({"brands", "designs", "collections", "materials", "product_models", "skus", "production_orders", "production_batches", "product_instances"})
    EDITABLE = frozenset({"brands", "designs", "collections", "materials", "product_models", "skus", "product_instances"})
    PRODUCTION = frozenset({"production_orders", "production_batches"})

    def __init__(self, repository: FashionRepository) -> None:
        self._repository = repository

    @staticmethod
    def _audit(context: FashionRequestContext) -> Mapping[str, str]:
        return {"request_id": str(context.request_id), "subject": context.subject, "domain": "fashion"}

    def list(self, context: FashionRequestContext, resource: str) -> list[Mapping[str, Any]]:
        FashionAuthorization.require(context, FashionRole.READER, FashionRole.EDITOR, FashionRole.ADMIN)
        self._require_resource(resource, self.READABLE)
        return self._repository.list(resource)

    def get(self, context: FashionRequestContext, resource: str, resource_id: UUID) -> Mapping[str, Any] | None:
        FashionAuthorization.require(context, FashionRole.READER, FashionRole.EDITOR, FashionRole.ADMIN)
        self._require_resource(resource, self.READABLE)
        return self._repository.get(resource, resource_id)

    def create(self, context: FashionRequestContext, resource: str, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        self._require_resource(resource, self.EDITABLE | self.PRODUCTION)
        if resource in self.PRODUCTION:
            FashionAuthorization.require(context, FashionRole.PRODUCTION_OPERATOR, FashionRole.ADMIN)
        else:
            FashionAuthorization.require(context, FashionRole.EDITOR, FashionRole.ADMIN)
        self._reject_authority_escalation(payload)
        return self._repository.create(resource, payload, audit=self._audit(context))

    def update(self, context: FashionRequestContext, resource: str, resource_id: UUID, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        self._require_resource(resource, self.EDITABLE | self.PRODUCTION)
        if resource in self.PRODUCTION:
            FashionAuthorization.require(context, FashionRole.PRODUCTION_OPERATOR, FashionRole.ADMIN)
        else:
            FashionAuthorization.require(context, FashionRole.EDITOR, FashionRole.ADMIN)
        self._reject_authority_escalation(payload)
        return self._repository.update(resource, resource_id, payload, audit=self._audit(context))

    def append_lifecycle_event(self, context: FashionRequestContext, product_instance_id: UUID, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        FashionAuthorization.require(context, FashionRole.LIFECYCLE_RECORDER, FashionRole.ADMIN)
        self._reject_authority_escalation(payload)
        return self._repository.append_lifecycle_event(product_instance_id, payload, audit=self._audit(context))

    def submit_evidence_link(self, context: FashionRequestContext, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        FashionAuthorization.require(context, FashionRole.EVIDENCE_SUBMITTER, FashionRole.ADMIN)
        if payload.get("verification_state") == "verified":
            raise FashionContractError("Evidence submitters cannot self-verify evidence")
        self._reject_authority_escalation(payload)
        return self._repository.submit_evidence_link(payload, audit=self._audit(context))

    def verify_evidence_link(self, context: FashionRequestContext, evidence_link_id: UUID, verification_state: str) -> Mapping[str, Any]:
        FashionAuthorization.require(context, FashionRole.EVIDENCE_VERIFIER, FashionRole.ADMIN)
        if verification_state not in {"verified", "rejected", "superseded"}:
            raise FashionContractError("Unsupported evidence verification state")
        return self._repository.verify_evidence_link(evidence_link_id, verification_state, audit=self._audit(context))

    @staticmethod
    def _require_resource(resource: str, allowed: frozenset[str]) -> None:
        if resource not in allowed:
            raise FashionContractError(f"Unsupported Fashion resource: {resource}")

    @staticmethod
    def _reject_authority_escalation(payload: Mapping[str, Any]) -> None:
        forbidden = {
            "legal_owner", "creates_ownership", "binding_contract", "payment_final",
            "settlement_final", "settlement_status", "source_coin_ledger_mutation",
            "certification_authority", "rights_authority",
        }
        if forbidden.intersection(payload):
            raise FashionContractError("Payload attempts to assert authority outside the Fashion bounded context")
