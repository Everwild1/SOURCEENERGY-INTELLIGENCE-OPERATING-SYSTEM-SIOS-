"""SC-E07 identity, eligibility and compliance decision primitives."""

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Tuple
from uuid import UUID


class ComplianceResult(str, Enum):
    ALLOW = "ALLOW"
    DENY = "DENY"
    REVIEW = "REVIEW"
    RESTRICT = "RESTRICT"


@dataclass(frozen=True)
class PolicyProfile:
    profile_id: UUID
    version: str
    jurisdiction_ref: str
    active: bool = True
    mandatory_screening: bool = False

    def __post_init__(self) -> None:
        if not self.version.strip() or not self.jurisdiction_ref.strip():
            raise ValueError("version and jurisdiction_ref are required")


@dataclass(frozen=True)
class ComplianceDecision:
    decision_id: UUID
    subject_type: str
    subject_id: str
    operation_type: str
    policy_profile_id: UUID
    policy_version: str
    result: ComplianceResult
    reason_codes: Tuple[str, ...]
    evidence_refs: Tuple[str, ...] = ()
    valid_until: datetime | None = None

    def __post_init__(self) -> None:
        if not self.subject_type.strip() or not self.subject_id.strip():
            raise ValueError("subject identity is required")
        if not self.operation_type.strip() or not self.policy_version.strip():
            raise ValueError("operation_type and policy_version are required")
        if not self.reason_codes:
            raise ValueError("at least one reason code is required")

    def is_effective(self, now: datetime | None = None) -> bool:
        if self.valid_until is None:
            return True
        now = now or datetime.now(timezone.utc)
        boundary = self.valid_until
        if boundary.tzinfo is None:
            boundary = boundary.replace(tzinfo=timezone.utc)
        return now <= boundary

    def permits_execution(self) -> bool:
        return self.result is ComplianceResult.ALLOW and self.is_effective()


def evaluate_mandatory_control(
    *,
    profile: PolicyProfile,
    subject_known: bool,
    screening_available: bool,
    screening_clear: bool,
) -> ComplianceResult:
    """Fail closed when identity or a mandatory screening control is unavailable."""
    if not profile.active or not subject_known:
        return ComplianceResult.DENY
    if profile.mandatory_screening and not screening_available:
        return ComplianceResult.DENY
    if profile.mandatory_screening and not screening_clear:
        return ComplianceResult.REVIEW
    return ComplianceResult.ALLOW
