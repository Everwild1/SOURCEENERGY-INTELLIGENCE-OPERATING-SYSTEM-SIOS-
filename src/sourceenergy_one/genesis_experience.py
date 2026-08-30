from dataclasses import dataclass
from enum import Enum


class GenesisStage(str, Enum):
    IDENTITY = "identity"
    CONSENT = "consent"
    PURPOSE_DISCOVERY = "purpose_discovery"
    CODEX24_SYNTHESIS = "codex24_synthesis"
    HUMAN_REVIEW = "human_review"
    GENESIS_READY = "genesis_ready"


@dataclass(frozen=True)
class GenesisExperienceContext:
    identity_verified: bool = False
    consent_recorded: bool = False
    purpose_profile_complete: bool = False
    codex24_candidate_complete: bool = False
    human_approved: bool = False


def resolve_stage(context: GenesisExperienceContext) -> GenesisStage:
    """Resolve the next governed stage. Codex24 output never substitutes for human approval."""
    if not context.identity_verified:
        return GenesisStage.IDENTITY
    if not context.consent_recorded:
        return GenesisStage.CONSENT
    if not context.purpose_profile_complete:
        return GenesisStage.PURPOSE_DISCOVERY
    if not context.codex24_candidate_complete:
        return GenesisStage.CODEX24_SYNTHESIS
    if not context.human_approved:
        return GenesisStage.HUMAN_REVIEW
    return GenesisStage.GENESIS_READY


def can_create_genesis(context: GenesisExperienceContext) -> bool:
    return resolve_stage(context) is GenesisStage.GENESIS_READY
