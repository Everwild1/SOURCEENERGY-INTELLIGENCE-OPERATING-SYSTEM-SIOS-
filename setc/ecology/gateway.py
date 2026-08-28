"""ECO-E07 governed integration gateway contracts.

The gateway transports requests and receipts. It never converts Ecology state into
source-domain authority, execution, settlement finality, or ledger mutation.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Mapping, Sequence

from .domain import EcologyCorrelation, EcologyDomain, EcologyObjectReference, SetcOrganizationId


class GatewayAction(str, Enum):
    REGISTER_REFERENCE = "register_reference"
    REQUEST_MARKET_WORKFLOW = "request_market_workflow"
    REQUEST_CAPITAL_REVIEW = "request_capital_review"
    REQUEST_SETTLEMENT = "request_settlement"
    REQUEST_INSTITUTIONAL_REVIEW = "request_institutional_review"
    REQUEST_LOGISTICS_REVIEW = "request_logistics_review"
    REQUEST_PROVENANCE_REVIEW = "request_provenance_review"
    SUBMIT_REGENERATIVE_PROPOSAL = "submit_regenerative_proposal"


class ReceiptStatus(str, Enum):
    RECEIVED = "received"
    REJECTED = "rejected"
    ACCEPTED_FOR_REVIEW = "accepted_for_review"


_ALLOWED_ACTIONS: Mapping[EcologyDomain, frozenset[GatewayAction]] = {
    EcologyDomain.WIM: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_MARKET_WORKFLOW}),
    EcologyDomain.CAPITALIZATION: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_CAPITAL_REVIEW, GatewayAction.SUBMIT_REGENERATIVE_PROPOSAL}),
    EcologyDomain.SOURCE_COIN: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_SETTLEMENT}),
    EcologyDomain.HEI: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_INSTITUTIONAL_REVIEW, GatewayAction.SUBMIT_REGENERATIVE_PROPOSAL}),
    EcologyDomain.GSC: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_LOGISTICS_REVIEW}),
    EcologyDomain.RGL: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_LOGISTICS_REVIEW}),
    EcologyDomain.SETC: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_PROVENANCE_REVIEW}),
    EcologyDomain.SOURCE_BLOCK: frozenset({GatewayAction.REGISTER_REFERENCE, GatewayAction.REQUEST_PROVENANCE_REVIEW}),
    EcologyDomain.EXTERNAL_AUTHORITY: frozenset({GatewayAction.REGISTER_REFERENCE}),
}

_MATERIAL_ACTIONS = frozenset({
    GatewayAction.REQUEST_MARKET_WORKFLOW,
    GatewayAction.REQUEST_CAPITAL_REVIEW,
    GatewayAction.REQUEST_SETTLEMENT,
    GatewayAction.REQUEST_INSTITUTIONAL_REVIEW,
    GatewayAction.REQUEST_LOGISTICS_REVIEW,
    GatewayAction.REQUEST_PROVENANCE_REVIEW,
    GatewayAction.SUBMIT_REGENERATIVE_PROPOSAL,
})


@dataclass(frozen=True)
class GatewayRequest:
    request_id: str
    contract_version: str
    target_domain: EcologyDomain
    action: GatewayAction
    correlation: EcologyCorrelation
    subject: EcologyObjectReference
    references: Sequence[EcologyObjectReference] = ()
    organization_id: SetcOrganizationId | None = None
    requested_at: datetime | None = None
    attributes: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.request_id.strip():
            raise ValueError("request_id is required")
        if self.contract_version != "1.0":
            raise ValueError("unsupported gateway contract version")
        allowed = _ALLOWED_ACTIONS.get(self.target_domain, frozenset())
        if self.action not in allowed:
            raise ValueError("action is not allowlisted for target domain")
        if self.action in _MATERIAL_ACTIONS and not self.correlation.idempotency_key:
            raise ValueError("material gateway requests require idempotency")
        if self.requested_at is not None and self.requested_at.tzinfo is None:
            raise ValueError("requested_at must be timezone-aware")

    @property
    def is_execution_instruction(self) -> bool:
        return False

    @property
    def confers_source_authority(self) -> bool:
        return False

    @property
    def confers_settlement_finality(self) -> bool:
        return False

    @property
    def may_bypass_release_gate(self) -> bool:
        return False


@dataclass(frozen=True)
class GatewayReceipt:
    receipt_id: str
    request_id: str
    target_domain: EcologyDomain
    status: ReceiptStatus
    authoritative_result_reference: EcologyObjectReference | None = None
    received_at: datetime | None = None
    message: str | None = None

    def __post_init__(self) -> None:
        if not self.receipt_id.strip() or not self.request_id.strip():
            raise ValueError("receipt and request identifiers are required")
        if self.received_at is not None and self.received_at.tzinfo is None:
            raise ValueError("received_at must be timezone-aware")
        if self.authoritative_result_reference is not None and self.authoritative_result_reference.domain is not self.target_domain:
            raise ValueError("authoritative result reference must belong to target domain")

    @property
    def proves_execution(self) -> bool:
        return False

    @property
    def proves_settlement_finality(self) -> bool:
        return False


def allowed_actions(target_domain: EcologyDomain) -> frozenset[GatewayAction]:
    return _ALLOWED_ACTIONS.get(target_domain, frozenset())
