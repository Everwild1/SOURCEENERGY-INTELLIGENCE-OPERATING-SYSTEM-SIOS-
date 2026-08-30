from dataclasses import dataclass
from hashlib import sha256
import json
from typing import Mapping, Sequence

from src.sourceenergy_one.genesis_experience import GenesisExperienceContext, can_create_genesis


REQUIRED_IMPACT_HORIZONS = ("present", "1", "5", "10", "25", "50", "100")
REQUIRED_4P_DIMENSIONS = ("purpose", "product", "people", "profit")


class GenesisBoundaryError(ValueError):
    """Raised when an authoritative Genesis candidate fails a governance invariant."""


@dataclass(frozen=True)
class FourPDimension:
    statement: str
    evidence_refs: Sequence[str]
    source_hash: str
    version: str


@dataclass(frozen=True)
class FourPProfile:
    purpose: FourPDimension
    product: FourPDimension
    people: FourPDimension
    profit: FourPDimension
    approved_by: str
    approval_attestation: str
    version: str = "4p-v1"


@dataclass(frozen=True)
class GenesisCandidate:
    subject_id: str
    subject_type: str
    schema_version: str
    purpose_profile_id: str
    purpose_source_hash: str
    approved_mvp_artifact_id: str
    approved_mvp_hash: str
    impact_report_id: str
    impact_report_hash: str
    impact_horizons: Mapping[str, str]
    consent_ids: Sequence[str]
    codex24_package_version: str
    jurisdiction: str
    authorizing_actor_id: str
    authorization_attestation: str
    economic_4p_profile: FourPProfile
    prior_genesis_id: str | None = None


def _required_text(name: str, value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise GenesisBoundaryError(f"{name} is required")
    return normalized


def _validate_4p(profile: FourPProfile) -> None:
    _required_text("economic_4p_profile.version", profile.version)
    _required_text("economic_4p_profile.approved_by", profile.approved_by)
    _required_text("economic_4p_profile.approval_attestation", profile.approval_attestation)
    for name in REQUIRED_4P_DIMENSIONS:
        dimension = getattr(profile, name)
        _required_text(f"economic_4p_profile.{name}.statement", dimension.statement)
        _required_text(f"economic_4p_profile.{name}.source_hash", dimension.source_hash)
        _required_text(f"economic_4p_profile.{name}.version", dimension.version)
        if not dimension.evidence_refs or any(not ref.strip() for ref in dimension.evidence_refs):
            raise GenesisBoundaryError(f"economic_4p_profile.{name} requires evidence")


def validate_candidate(context: GenesisExperienceContext, candidate: GenesisCandidate) -> None:
    """Fail closed unless the experience is human-approved and provenance is complete."""
    if not can_create_genesis(context):
        raise GenesisBoundaryError("Genesis Experience is not human-approved and Genesis-ready")

    required = {
        "subject_id": candidate.subject_id,
        "subject_type": candidate.subject_type,
        "schema_version": candidate.schema_version,
        "purpose_profile_id": candidate.purpose_profile_id,
        "purpose_source_hash": candidate.purpose_source_hash,
        "approved_mvp_artifact_id": candidate.approved_mvp_artifact_id,
        "approved_mvp_hash": candidate.approved_mvp_hash,
        "impact_report_id": candidate.impact_report_id,
        "impact_report_hash": candidate.impact_report_hash,
        "codex24_package_version": candidate.codex24_package_version,
        "jurisdiction": candidate.jurisdiction,
        "authorizing_actor_id": candidate.authorizing_actor_id,
        "authorization_attestation": candidate.authorization_attestation,
    }
    for name, value in required.items():
        _required_text(name, value)

    if not candidate.consent_ids or any(not consent_id.strip() for consent_id in candidate.consent_ids):
        raise GenesisBoundaryError("at least one valid consent reference is required")

    missing_horizons = [h for h in REQUIRED_IMPACT_HORIZONS if not candidate.impact_horizons.get(h, "").strip()]
    if missing_horizons:
        raise GenesisBoundaryError(f"impact horizons incomplete: {', '.join(missing_horizons)}")

    _validate_4p(candidate.economic_4p_profile)


def _dimension_payload(dimension: FourPDimension) -> dict:
    return {
        "statement": dimension.statement,
        "evidence_refs": sorted(dimension.evidence_refs),
        "source_hash": dimension.source_hash,
        "version": dimension.version,
    }


def canonical_payload(candidate: GenesisCandidate) -> dict:
    """Return the immutable-record payload; raw Purpose Discovery narrative is intentionally excluded."""
    profile = candidate.economic_4p_profile
    return {
        "subject_id": candidate.subject_id,
        "subject_type": candidate.subject_type,
        "schema_version": candidate.schema_version,
        "purpose_profile_id": candidate.purpose_profile_id,
        "purpose_source_hash": candidate.purpose_source_hash,
        "approved_mvp_artifact_id": candidate.approved_mvp_artifact_id,
        "approved_mvp_hash": candidate.approved_mvp_hash,
        "impact_report_id": candidate.impact_report_id,
        "impact_report_hash": candidate.impact_report_hash,
        "impact_horizons": {h: candidate.impact_horizons[h] for h in REQUIRED_IMPACT_HORIZONS},
        "consent_ids": sorted(candidate.consent_ids),
        "codex24_package_version": candidate.codex24_package_version,
        "jurisdiction": candidate.jurisdiction,
        "authorizing_actor_id": candidate.authorizing_actor_id,
        "authorization_attestation": candidate.authorization_attestation,
        "human_approved": True,
        "economic_4p_profile": {
            "version": profile.version,
            "approved_by": profile.approved_by,
            "approval_attestation": profile.approval_attestation,
            "purpose": _dimension_payload(profile.purpose),
            "product": _dimension_payload(profile.product),
            "people": _dimension_payload(profile.people),
            "profit": _dimension_payload(profile.profit),
        },
        "prior_genesis_id": candidate.prior_genesis_id,
    }


def provenance_hash(candidate: GenesisCandidate) -> str:
    payload = canonical_payload(candidate)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return sha256(encoded).hexdigest()
