"""Institutional investigation and enforcement-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class InvestigationState(StrEnum):
    INTAKE = "INTAKE"
    OPEN = "OPEN"
    INVESTIGATING = "INVESTIGATING"
    FINDING_ISSUED = "FINDING_ISSUED"
    CLOSED = "CLOSED"


class FindingDisposition(StrEnum):
    SUBSTANTIATED = "SUBSTANTIATED"
    UNSUBSTANTIATED = "UNSUBSTANTIATED"
    INCONCLUSIVE = "INCONCLUSIVE"


class EnforcementState(StrEnum):
    PROPOSED = "PROPOSED"
    IMPOSED = "IMPOSED"
    APPEALED = "APPEALED"
    STAYED = "STAYED"
    EXECUTED = "EXECUTED"
    CLOSED = "CLOSED"


@dataclass(frozen=True, slots=True)
class InvestigationMandate:
    mandate_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    investigating_organization_id: SETCIdentifier
    scope: str
    authority_reference: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.investigating_organization_id:
            raise ValueError("investigation mandate requires an independent investigator")
        if not self.scope.strip() or not self.authority_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("investigation mandate requires scope, authority, and evidence")


@dataclass(frozen=True, slots=True)
class InvestigationCase:
    case_id: SETCIdentifier
    mandate_id: SETCIdentifier
    allegation_reference: str
    allegation: str
    state: InvestigationState = InvestigationState.INTAKE
    opened_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.allegation_reference.strip() or not self.allegation.strip():
            raise ValueError("investigation case requires allegation reference and allegation")


@dataclass(frozen=True, slots=True)
class EvidenceCustodyRecord:
    custody_id: SETCIdentifier
    case_id: SETCIdentifier
    evidence_reference: str
    custodian_organization_id: SETCIdentifier
    received_at: datetime
    source_reference: str

    def __post_init__(self) -> None:
        if not self.evidence_reference.strip() or not self.source_reference.strip():
            raise ValueError("evidence custody requires evidence and source references")


@dataclass(frozen=True, slots=True)
class InvestigationFinding:
    finding_id: SETCIdentifier
    case_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    investigating_organization_id: SETCIdentifier
    disposition: FindingDisposition
    finding: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.investigating_organization_id:
            raise ValueError("investigation finding requires independent investigator")
        if not self.finding.strip():
            raise ValueError("investigation finding cannot be blank")
        if not self.evidence_references:
            raise ValueError("investigation finding requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("investigation evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class EnforcementDetermination:
    determination_id: SETCIdentifier
    finding_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    determining_organization_id: SETCIdentifier
    action: str
    authority_reference: str
    state: EnforcementState = EnforcementState.PROPOSED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.determining_organization_id:
            raise ValueError("enforcement determination requires distinct subject and determining organizations")
        if not self.action.strip() or not self.authority_reference.strip():
            raise ValueError("enforcement determination requires action and authority")
        if self.state in {EnforcementState.IMPOSED, EnforcementState.EXECUTED, EnforcementState.CLOSED} and not self.evidence_references:
            raise ValueError("material enforcement state requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("enforcement evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class EnforcementAppeal:
    appeal_id: SETCIdentifier
    determination_id: SETCIdentifier
    appellant_organization_id: SETCIdentifier
    reviewing_organization_id: SETCIdentifier
    grounds: str
    evidence_reference: str

    def __post_init__(self) -> None:
        if self.appellant_organization_id == self.reviewing_organization_id:
            raise ValueError("enforcement appeal requires independent reviewer")
        if not self.grounds.strip() or not self.evidence_reference.strip():
            raise ValueError("enforcement appeal requires grounds and evidence")


@dataclass(frozen=True, slots=True)
class EnforcementExecutionRecord:
    execution_id: SETCIdentifier
    determination_id: SETCIdentifier
    executing_organization_id: SETCIdentifier
    action: str
    executed_at: datetime
    evidence_reference: str

    def __post_init__(self) -> None:
        if not self.action.strip() or not self.evidence_reference.strip():
            raise ValueError("enforcement execution requires action and evidence")


@dataclass(frozen=True, slots=True)
class EnforcementExecutionVerification:
    verification_id: SETCIdentifier
    execution_id: SETCIdentifier
    executing_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    verified: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.executing_organization_id == self.verifier_organization_id:
            raise ValueError("enforcement execution verification requires an independent verifier")
        if self.verified and not self.evidence_references:
            raise ValueError("verified enforcement execution requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("execution verification evidence references cannot contain blanks")
