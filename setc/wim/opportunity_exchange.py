"""Non-binding opportunity, procurement and commercialization exchange contracts."""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import StrEnum
from .domain import OrganizationBinding

class OpportunityType(StrEnum):
    BUY="buy"; SELL="sell"; SOURCE="source"; SUPPLY="supply"; PROCURE="procure"; INVEST="invest"; PARTNER="partner"; EXPORT="export"; IMPORT="import"; COMMERCIALIZE="commercialize"

class OpportunityStatus(StrEnum):
    DRAFT="draft"; OPEN="open"; MATCHED="matched"; UNDER_REVIEW="under_review"; CLOSED="closed"; CANCELLED="cancelled"; EXPIRED="expired"; RESTRICTED="restricted"

class ResponseType(StrEnum):
    INTEREST="interest"; OFFER="offer"; PROPOSAL="proposal"; BID="bid"; PARTNERSHIP="partnership"; INFORMATION="information"

@dataclass(frozen=True, slots=True)
class Opportunity:
    originator: OrganizationBinding
    opportunity_type: OpportunityType
    title: str
    status: OpportunityStatus=OpportunityStatus.DRAFT
    provenance_reference: str=""
    opens_at: datetime|None=None
    closes_at: datetime|None=None

    def require_open(self, now: datetime|None=None) -> None:
        self.originator.require_commercial_activity()
        if self.status is not OpportunityStatus.OPEN: raise ValueError("opportunity must be open")
        if not self.provenance_reference.strip(): raise ValueError("open opportunity requires provenance")
        instant=now or datetime.now(timezone.utc)
        if self.opens_at and instant < self.opens_at: raise ValueError("opportunity has not opened")
        if self.closes_at and instant >= self.closes_at: raise ValueError("opportunity has expired")
        if self.opens_at and self.closes_at and self.closes_at <= self.opens_at: raise ValueError("invalid opportunity window")

    @property
    def creates_transaction_or_investment_authorization(self)->bool: return False

@dataclass(frozen=True, slots=True)
class OpportunityResponse:
    opportunity: Opportunity
    responder: OrganizationBinding
    response_type: ResponseType
    response_reference: str

    def require_eligible(self) -> None:
        self.opportunity.require_open()
        self.responder.require_commercial_activity()
        if self.responder.setc_organization_id == self.opportunity.originator.setc_organization_id: raise ValueError("originator cannot self-respond")
        if not self.response_reference.strip(): raise ValueError("response reference is required")

    @property
    def creates_award_or_settlement(self)->bool: return False
