"""ECO-E09 fail-closed release assurance for the Ecology Block."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Sequence


class ReleaseDisposition(str, Enum):
    NO_GO = "no_go"
    CONDITIONAL_GO = "conditional_go"
    GO = "go"


class ControlSeverity(str, Enum):
    MANDATORY = "mandatory"
    ADVISORY = "advisory"


@dataclass(frozen=True)
class ReadinessControl:
    control_id: str
    description: str
    severity: ControlSeverity
    satisfied: bool
    evidence_references: Sequence[str] = ()
    permits_conditional_mode: bool = False

    def __post_init__(self) -> None:
        if not self.control_id.strip() or not self.description.strip():
            raise ValueError("control identity and description are required")
        if self.satisfied and not self.evidence_references:
            raise ValueError("satisfied controls require evidence")


@dataclass(frozen=True)
class ReleaseAssessment:
    disposition: ReleaseDisposition
    controls: Sequence[ReadinessControl]
    conditional_constraints: Sequence[str]

    @property
    def authorizes_financial_execution(self) -> bool:
        return False

    @property
    def confers_settlement_finality(self) -> bool:
        return False


def evaluate_readiness(controls: Sequence[ReadinessControl]) -> ReleaseAssessment:
    if not controls:
        return ReleaseAssessment(ReleaseDisposition.NO_GO, (), ("no_controls_evidenced",))

    failed_mandatory = [c for c in controls if c.severity is ControlSeverity.MANDATORY and not c.satisfied]
    if not failed_mandatory:
        return ReleaseAssessment(ReleaseDisposition.GO, tuple(controls), ())

    if all(c.permits_conditional_mode for c in failed_mandatory):
        constraints = (
            "non_economic_control_plane_only",
            "no_settlement_finality",
            "no_source_coin_production_effects",
            "no_treasury_or_ledger_mutation",
            "no_external_authority_substitution",
        )
        return ReleaseAssessment(ReleaseDisposition.CONDITIONAL_GO, tuple(controls), constraints)

    return ReleaseAssessment(
        ReleaseDisposition.NO_GO,
        tuple(controls),
        tuple(f"blocked:{c.control_id}" for c in failed_mandatory),
    )


def current_ecology_assessment() -> ReleaseAssessment:
    """Current evidence posture after E08; deliberately does not overstate readiness."""
    controls = (
        ReadinessControl("E01_E08_ENGINEERING", "ECO-E01 through E08 contracts and CI evidence", ControlSeverity.MANDATORY, True, ("PR-234..245",)),
        ReadinessControl("AUTHORITY_BOUNDARIES", "Cross-domain authority non-escalation tests", ControlSeverity.MANDATORY, True, ("Ecology-Block-CI-14",)),
        ReadinessControl("SYNTHETIC_PILOT", "Closed-loop synthetic pilot", ControlSeverity.MANDATORY, True, ("PR-245",)),
        ReadinessControl("PRODUCTION_GATEWAY_SECURITY", "Production authentication, authorization, rate limiting and observability", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("RECOVERY_ROLLBACK", "Production recovery and rollback evidence", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("E04_CORRECTION_HISTORY", "Projection correction and supersession persistence", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("E04_AUTHORITY_MAPPING", "Database-enforced domain-to-source-authority mapping", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("SOURCE_COIN_RELEASE", "Independent Source Coin production release gate", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("EXTERNAL_SETTLEMENT_AUTHORITY", "External settlement/legal authority evidence", ControlSeverity.MANDATORY, False, (), True),
        ReadinessControl("POSTGIS_SHARED_BACKEND", "Shared backend PostGIS findings compatibility-reviewed", ControlSeverity.ADVISORY, False),
    )
    return evaluate_readiness(controls)
