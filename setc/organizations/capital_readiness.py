"""Capital readiness assessment primitives governed by SETC-116."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class ReadinessPathway(StrEnum):
    GRANT = "GRANT"
    DEBT = "DEBT"
    EQUITY = "EQUITY"
    PROCUREMENT = "PROCUREMENT"
    INSTITUTIONAL_CAPITAL = "INSTITUTIONAL_CAPITAL"
    PROJECT_FINANCE = "PROJECT_FINANCE"


class AssessmentState(StrEnum):
    REQUESTED = "REQUESTED"
    UNDER_REVIEW = "UNDER_REVIEW"
    DEFICIENT = "DEFICIENT"
    REMEDIATION = "REMEDIATION"
    REASSESSMENT = "REASSESSMENT"
    APPROVED = "APPROVED"
    CONDITIONALLY_APPROVED = "CONDITIONALLY_APPROVED"
    DECLINED = "DECLINED"
    CLOSED = "CLOSED"


class CertificationState(StrEnum):
    ACTIVE = "ACTIVE"
    CONDITIONAL = "CONDITIONAL"
    EXPIRED = "EXPIRED"
    SUSPENDED = "SUSPENDED"
    REVOKED = "REVOKED"


@dataclass(frozen=True, slots=True)
class AssessmentFramework:
    framework_id: SETCIdentifier
    name: str
    pathway: ReadinessPathway
    version: str

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.version.strip():
            raise ValueError("framework name and version are required")


@dataclass(frozen=True, slots=True)
class AssessmentDimension:
    dimension_id: SETCIdentifier
    framework_id: SETCIdentifier
    name: str
    weight: float

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("dimension name cannot be blank")
        if self.weight <= 0:
            raise ValueError("dimension weight must be positive")


@dataclass(frozen=True, slots=True)
class ReadinessAssessment:
    assessment_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    framework_id: SETCIdentifier
    reviewer_organization_id: SETCIdentifier
    state: AssessmentState = AssessmentState.REQUESTED
    requested_at: datetime | None = None
    evidence_references: tuple[str, ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.reviewer_organization_id:
            raise ValueError("readiness assessment requires independent reviewer organization")
        if any(not ref.strip() for ref in self.evidence_references):
            raise ValueError("evidence references cannot contain blanks")


@dataclass(frozen=True, slots=True)
class AssessmentFinding:
    finding_id: SETCIdentifier
    assessment_id: SETCIdentifier
    dimension_id: SETCIdentifier
    score: float
    evidence_reference: str
    deficiency: str | None = None

    def __post_init__(self) -> None:
        if self.score < 0 or self.score > 100:
            raise ValueError("assessment score must be between 0 and 100")
        if not self.evidence_reference.strip():
            raise ValueError("finding requires evidence")
        if self.deficiency is not None and not self.deficiency.strip():
            raise ValueError("deficiency cannot be blank")


@dataclass(frozen=True, slots=True)
class RemediationAction:
    remediation_id: SETCIdentifier
    assessment_id: SETCIdentifier
    finding_id: SETCIdentifier
    action: str
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if not self.action.strip():
            raise ValueError("remediation action cannot be blank")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")


@dataclass(frozen=True, slots=True)
class ReadinessCertification:
    certification_id: SETCIdentifier
    assessment_id: SETCIdentifier
    subject_organization_id: SETCIdentifier
    pathway: ReadinessPathway
    state: CertificationState
    issued_by_organization_id: SETCIdentifier
    issued_at: datetime
    expires_at: datetime | None = None
    conditions: tuple[str, ...] = field(default_factory=tuple)
    evidence_reference: str | None = None

    def __post_init__(self) -> None:
        if self.subject_organization_id == self.issued_by_organization_id:
            raise ValueError("readiness certification requires independent issuer")
        if self.expires_at is not None and self.expires_at <= self.issued_at:
            raise ValueError("certification expiry must follow issuance")
        if any(not condition.strip() for condition in self.conditions):
            raise ValueError("certification conditions cannot contain blanks")
        if self.state == CertificationState.CONDITIONAL and not self.conditions:
            raise ValueError("conditional certification requires at least one condition")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
