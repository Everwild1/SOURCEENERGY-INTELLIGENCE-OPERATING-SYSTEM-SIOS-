"""Institutional assurance and audit-governance primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class AssuranceEngagementState(StrEnum):
    PLANNED = "PLANNED"
    ACTIVE = "ACTIVE"
    FIELDWORK_COMPLETE = "FIELDWORK_COMPLETE"
    OPINION_ISSUED = "OPINION_ISSUED"
    CLOSED = "CLOSED"


class AuditFindingSeverity(StrEnum):
    LOW = "LOW"
    MODERATE = "MODERATE"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class AssuranceOpinion(StrEnum):
    UNMODIFIED = "UNMODIFIED"
    QUALIFIED = "QUALIFIED"
    ADVERSE = "ADVERSE"
    DISCLAIMER = "DISCLAIMER"


@dataclass(frozen=True, slots=True)
class AssuranceEngagement:
    engagement_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    auditor_organization_id: SETCIdentifier
    engagement_reference: str
    scope: str
    state: AssuranceEngagementState = AssuranceEngagementState.PLANNED
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.auditor_organization_id:
            raise ValueError("assurance engagement requires an independent auditor")
        if not self.engagement_reference.strip() or not self.scope.strip():
            raise ValueError("assurance engagement requires reference and scope")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("engagement evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AuditEvidenceRecord:
    evidence_id: SETCIdentifier
    engagement_id: SETCIdentifier
    collected_by_organization_id: SETCIdentifier
    source_reference: str
    evidence_reference: str
    collected_at: datetime

    def __post_init__(self) -> None:
        if not self.source_reference.strip() or not self.evidence_reference.strip():
            raise ValueError("audit evidence requires source and evidence reference")


@dataclass(frozen=True, slots=True)
class AuditFinding:
    finding_id: SETCIdentifier
    engagement_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    finding: str
    severity: AuditFindingSeverity
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.finding.strip():
            raise ValueError("audit finding cannot be blank")
        if not self.evidence_references:
            raise ValueError("audit finding requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("finding evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class ManagementResponse:
    response_id: SETCIdentifier
    finding_id: SETCIdentifier
    responding_organization_id: SETCIdentifier
    response: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.response.strip():
            raise ValueError("management response cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class AuditRemediation:
    remediation_id: SETCIdentifier
    finding_id: SETCIdentifier
    responsible_organization_id: SETCIdentifier
    action: str
    due_at: datetime | None = None
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("audit remediation action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class RemediationVerification:
    verification_id: SETCIdentifier
    remediation_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    verifier_organization_id: SETCIdentifier
    verified: bool
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.verifier_organization_id:
            raise ValueError("remediation verification requires an independent verifier")
        if self.verified and not self.evidence_references:
            raise ValueError("verified remediation requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("verification evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AssuranceOpinionRecord:
    opinion_id: SETCIdentifier
    engagement_id: SETCIdentifier
    issuing_organization_id: SETCIdentifier
    opinion: AssuranceOpinion
    rationale: str
    evidence_references: tuple[str, ...] = field(default_factory=tuple)
    issued_at: datetime | None = None

    def __post_init__(self) -> None:
        if not self.rationale.strip():
            raise ValueError("assurance opinion requires rationale")
        if not self.evidence_references:
            raise ValueError("assurance opinion requires evidence")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("opinion evidence references cannot contain blanks")
