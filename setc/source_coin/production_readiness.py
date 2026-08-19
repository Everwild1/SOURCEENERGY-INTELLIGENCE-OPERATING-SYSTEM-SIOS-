"""SC-E12 production-readiness controls.

This module can attest readiness; it cannot activate Source Coin production economics.
"""
from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable, Mapping, Tuple


class FindingSeverity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class FindingDisposition(str, Enum):
    OPEN = "OPEN"
    MITIGATED = "MITIGATED"
    ACCEPTED = "ACCEPTED"
    CLOSED = "CLOSED"


@dataclass(frozen=True)
class AuditFinding:
    finding_id: str
    severity: FindingSeverity
    disposition: FindingDisposition
    evidence_ref: str

    @property
    def blocks_release(self) -> bool:
        return self.disposition is FindingDisposition.OPEN and self.severity in {
            FindingSeverity.HIGH,
            FindingSeverity.CRITICAL,
        }


@dataclass(frozen=True)
class EvidenceItem:
    control_id: str
    evidence_ref: str
    verified: bool


@dataclass(frozen=True)
class ConfigurationFreeze:
    release_sha: str
    migration_head: str
    policy_profile_version: str
    network_id: str

    def __post_init__(self) -> None:
        for value in (self.release_sha, self.migration_head, self.policy_profile_version, self.network_id):
            if not value.strip():
                raise ValueError("configuration freeze values are required")


@dataclass(frozen=True)
class GovernanceAuthorization:
    authorization_id: str
    approving_authority: str
    approved_scope: Tuple[str, ...]
    evidence_ref: str
    explicit: bool = False

    def __post_init__(self) -> None:
        if not self.authorization_id.strip() or not self.approving_authority.strip() or not self.evidence_ref.strip():
            raise ValueError("governance authorization must be fully evidenced")
        if not self.approved_scope:
            raise ValueError("approved_scope is required")


REQUIRED_EVIDENCE = tuple(f"SC-E{i:02d}" for i in range(1, 12)) + (
    "SUPABASE_PRODUCTION_SEPARATION",
    "RLS_AUTH_FUNCTION_REVIEW",
    "KEY_CUSTODY_READINESS",
    "DEPENDENCY_SECURITY_SCAN",
    "PRIVACY_LEGAL_COMPLIANCE",
    "ROLLBACK_EXERCISE",
    "EMERGENCY_PROCEDURE_EXERCISE",
)


@dataclass(frozen=True)
class ProductionReadinessGate:
    evidence: Tuple[EvidenceItem, ...]
    findings: Tuple[AuditFinding, ...]
    freeze: ConfigurationFreeze
    production_secrets_separated: bool
    production_keys_established: bool
    rollback_exercised: bool
    emergency_procedure_exercised: bool
    authorization: GovernanceAuthorization | None = None

    def missing_controls(self) -> Tuple[str, ...]:
        verified = {item.control_id for item in self.evidence if item.verified}
        return tuple(control for control in REQUIRED_EVIDENCE if control not in verified)

    def readiness_failures(self) -> Tuple[str, ...]:
        failures = list(self.missing_controls())
        if any(finding.blocks_release for finding in self.findings):
            failures.append("MATERIAL_AUDIT_FINDINGS")
        if not self.production_secrets_separated:
            failures.append("PRODUCTION_SECRET_SEPARATION")
        if not self.production_keys_established:
            failures.append("PRODUCTION_KEY_CUSTODY")
        if not self.rollback_exercised:
            failures.append("ROLLBACK_NOT_EXERCISED")
        if not self.emergency_procedure_exercised:
            failures.append("EMERGENCY_PROCEDURE_NOT_EXERCISED")
        return tuple(failures)

    @property
    def audit_ready(self) -> bool:
        return not self.readiness_failures()

    @property
    def activation_authorized(self) -> bool:
        """Authorization is separate from audit readiness and must be explicit."""
        return self.audit_ready and self.authorization is not None and self.authorization.explicit

    def assert_activation_authorized(self, capability: str) -> None:
        if not self.activation_authorized:
            raise PermissionError("production activation is not explicitly authorized")
        assert self.authorization is not None
        if capability not in self.authorization.approved_scope:
            raise PermissionError("capability is outside approved production scope")


def activation_environment_defaults() -> Mapping[str, str]:
    """SC-E12 never flips these controls; activation is a separate governed operation."""
    return {
        "SOURCE_COIN_MINT_ENABLED": "false",
        "SOURCE_COIN_BURN_ENABLED": "false",
        "SOURCE_COIN_PRODUCTION_ECONOMY_ENABLED": "false",
    }
