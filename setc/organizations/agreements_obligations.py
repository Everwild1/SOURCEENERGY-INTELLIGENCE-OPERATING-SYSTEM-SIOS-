"""Institutional agreements and obligations governance for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class AgreementState(StrEnum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    TERMINATED = "TERMINATED"
    EXPIRED = "EXPIRED"


class ObligationState(StrEnum):
    PENDING = "PENDING"
    IN_PROGRESS = "IN_PROGRESS"
    SATISFIED = "SATISFIED"
    BREACHED = "BREACHED"
    WAIVED = "WAIVED"


class BreachState(StrEnum):
    ASSERTED = "ASSERTED"
    REVIEWED = "REVIEWED"
    CONFIRMED = "CONFIRMED"
    REMEDIATED = "REMEDIATED"
    WITHDRAWN = "WITHDRAWN"


@dataclass(frozen=True, slots=True)
class InstitutionalAgreement:
    agreement_id: SETCIdentifier
    organization_id: SETCIdentifier
    counterparty_organization_id: SETCIdentifier
    agreement_reference: str
    agreement_type: str
    effective_from: datetime
    effective_until: datetime | None = None
    state: AgreementState = AgreementState.DRAFT
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.organization_id == self.counterparty_organization_id:
            raise ValueError("agreement requires distinct counterparties")
        if not self.agreement_reference.strip() or not self.agreement_type.strip():
            raise ValueError("agreement requires reference and type")
        if self.effective_until is not None and self.effective_until <= self.effective_from:
            raise ValueError("agreement end must follow start")
        if self.state == AgreementState.ACTIVE and not self.evidence_references:
            raise ValueError("active agreement requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("agreement evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AgreementObligation:
    obligation_id: SETCIdentifier
    agreement_id: SETCIdentifier
    obligated_organization_id: SETCIdentifier
    beneficiary_organization_id: SETCIdentifier
    obligation: str
    due_at: datetime | None = None
    state: ObligationState = ObligationState.PENDING
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.obligated_organization_id == self.beneficiary_organization_id:
            raise ValueError("obligation requires distinct obligated and beneficiary organizations")
        if not self.obligation.strip():
            raise ValueError("obligation text cannot be blank")
        if self.state == ObligationState.SATISFIED and not self.evidence_references:
            raise ValueError("satisfied obligation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("obligation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AgreementAmendment:
    amendment_id: SETCIdentifier
    agreement_id: SETCIdentifier
    amendment_reference: str
    effective_at: datetime
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.amendment_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("agreement amendment requires reference and evidence")


@dataclass(frozen=True, slots=True)
class PerformanceEvidence:
    performance_id: SETCIdentifier
    obligation_id: SETCIdentifier
    performing_organization_id: SETCIdentifier
    observed_at: datetime
    result: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.result.strip() or not self.evidence_reference.strip():
            raise ValueError("performance evidence requires result and evidence")


@dataclass(frozen=True, slots=True)
class AgreementBreach:
    breach_id: SETCIdentifier
    agreement_id: SETCIdentifier
    obligation_id: SETCIdentifier | None
    asserting_organization_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    breach_description: str
    state: BreachState = BreachState.ASSERTED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.asserting_organization_id == self.subject_organization_id:
            raise ValueError("breach assertion requires distinct asserting and subject organizations")
        if not self.breach_description.strip():
            raise ValueError("breach description cannot be blank")
        if self.state == BreachState.CONFIRMED and not self.evidence_references:
            raise ValueError("confirmed breach requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("breach evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AgreementRemedy:
    remedy_id: SETCIdentifier
    breach_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    remedy: str
    due_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.remedy.strip():
            raise ValueError("agreement remedy cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class TerminationAuthorization:
    termination_id: SETCIdentifier
    agreement_id: SETCIdentifier
    requesting_organization_id: SETCIdentifier
    approving_organization_id: SETCIdentifier
    rationale: str
    authority_reference: str
    evidence_reference: str
    effective_at: datetime

    def __post_init__(self) -> None:
        if self.requesting_organization_id == self.approving_organization_id:
            raise ValueError("termination requester cannot self-approve")
        if not self.rationale.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("termination authorization requires rationale, authority, and evidence")
