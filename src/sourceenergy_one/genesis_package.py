from dataclasses import dataclass
from hashlib import sha256
import json
from typing import Mapping, Sequence

from src.sourceenergy_one.genesis_experience import GenesisExperienceContext, can_create_genesis


REQUIRED_IMPACT_HORIZONS = ("present", "1", "5", "10", "25", "50", "100")


class GenesisBoundaryError(ValueError):
    """Raised when an authoritative Genesis candidate fails a governance invariant."""


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
    prior_genesis_id: str | None = None


def _required_text(name: str, value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise GenesisBoundaryError(f"{name} is required")
    return normalized


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


def canonical_payload(candidate: GenesisCandidate) -> dict:
    """Return the immutable-record payload; raw Purpose Discovery narrative is intentionally excluded."""
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
        "prior_genesis_id": candidate.prior_genesis_id,
    }


def provenance_hash(candidate: GenesisCandidate) -> str:
    payload = canonical_payload(candidate)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return sha256(encoded).hexdigest()
