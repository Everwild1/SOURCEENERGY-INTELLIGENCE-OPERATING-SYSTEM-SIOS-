"""Pre-approval evidence-validation and adjudication contracts for WNF-7.

These contracts validate human-stage inputs before trusted persistence. They do
not validate evidence by themselves, appoint reviewers, advance a gate, or
authorize execution or production.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import StrEnum
import re
from typing import Any
from uuid import UUID

from .models import WNF7ContractError
from .review import (
    ReviewerRole,
    _controlled_ref,
    _safe_metadata,
    _text,
    _timestamp,
    _uuid,
)


class EvidenceFreshness(StrEnum):
    CURRENT = "CURRENT"
    STALE = "STALE"
    EXPIRED = "EXPIRED"
    NOT_APPLICABLE = "NOT_APPLICABLE"


class EvidenceValidationStatus(StrEnum):
    VALIDATED = "VALIDATED"
    GAP = "GAP"
    CONTRADICTORY = "CONTRADICTORY"
    REJECTED = "REJECTED"


class DecisionDisposition(StrEnum):
    CONFIRM = "CONFIRM"
    OVERRIDE = "OVERRIDE"
    HOLD = "HOLD"


class AdjudicationStatus(StrEnum):
    IN_REVIEW = "IN_REVIEW"
    COMPLETE = "COMPLETE"
    HOLD = "HOLD"
    REMEDIATION_REQUIRED = "REMEDIATION_REQUIRED"


_EVIDENCE_FIELDS = frozenset(
    {
        "pilot_code",
        "scenario_code",
        "candidate_evidence_ref",
        "validation_evidence_ref",
        "source_system",
        "content_sha256",
        "freshness_status",
        "validation_status",
        "observed_at",
        "validated_at",
        "validated_by",
        "validated_by_role_code",
        "rationale_summary",
        "metadata",
    }
)
_REQUIRED_EVIDENCE_FIELDS = _EVIDENCE_FIELDS - {"metadata"}
_DECISION_FIELDS = frozenset(
    {
        "pilot_code",
        "scenario_code",
        "reviewer_subject_id",
        "reviewer_role_code",
        "disposition",
        "decision_status",
        "rationale_summary",
        "attestation_ref",
        "decided_at",
        "evidence_refs",
        "automated_result_ref",
        "metadata",
    }
)
_REQUIRED_DECISION_FIELDS = _DECISION_FIELDS - {"attestation_ref", "metadata"}


def _strict_payload(
    name: str,
    payload: Mapping[str, Any],
    *,
    allowed: frozenset[str],
    required: frozenset[str],
) -> None:
    unknown = sorted(set(payload) - allowed)
    if unknown:
        raise WNF7ContractError(f"{name} contains prohibited fields: {', '.join(unknown)}")
    missing = sorted(required - set(payload))
    if missing:
        raise WNF7ContractError(f"{name} is missing required fields: {', '.join(missing)}")


def _scenario_code(value: Any) -> str:
    scenario = _text("scenario_code", value)
    if not re.fullmatch(r"SCN-\d{3}", scenario):
        raise WNF7ContractError("scenario_code must use the SCN-nnn format")
    return scenario


def _sha256(value: Any) -> str:
    digest = _text("content_sha256", value)
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise WNF7ContractError("content_sha256 must be a lowercase SHA-256 digest")
    return digest


@dataclass(frozen=True, slots=True)
class EvidenceValidationSubmission:
    scenario_code: str
    candidate_evidence_ref: str
    validation_evidence_ref: str
    source_system: str
    content_sha256: str
    freshness_status: EvidenceFreshness
    validation_status: EvidenceValidationStatus
    observed_at: datetime
    validated_at: datetime
    validated_by: UUID
    validated_by_role_code: ReviewerRole
    rationale_summary: str
    metadata: Mapping[str, Any] = field(default_factory=dict)
    pilot_code: str = "PILOT-7D-001"

    def __post_init__(self) -> None:
        if self.pilot_code != "PILOT-7D-001":
            raise WNF7ContractError("evidence validation is restricted to PILOT-7D-001")
        object.__setattr__(self, "scenario_code", _scenario_code(self.scenario_code))
        object.__setattr__(
            self,
            "candidate_evidence_ref",
            _controlled_ref("candidate_evidence_ref", self.candidate_evidence_ref),
        )
        object.__setattr__(
            self,
            "validation_evidence_ref",
            _controlled_ref("validation_evidence_ref", self.validation_evidence_ref),
        )
        if self.candidate_evidence_ref == self.validation_evidence_ref:
            raise WNF7ContractError("validation evidence must be a new governed reference")
        object.__setattr__(self, "source_system", _text("source_system", self.source_system))
        object.__setattr__(self, "content_sha256", _sha256(self.content_sha256))
        try:
            object.__setattr__(self, "freshness_status", EvidenceFreshness(self.freshness_status))
            object.__setattr__(
                self,
                "validation_status",
                EvidenceValidationStatus(self.validation_status),
            )
            object.__setattr__(
                self,
                "validated_by_role_code",
                ReviewerRole(self.validated_by_role_code),
            )
        except ValueError as exc:
            raise WNF7ContractError("evidence validation contains a non-canonical state") from exc
        object.__setattr__(
            self,
            "validated_by",
            _uuid("validated_by", str(self.validated_by)),
        )
        if not isinstance(self.observed_at, datetime) or not isinstance(self.validated_at, datetime):
            raise WNF7ContractError("evidence timestamps must be datetime values")
        for name, value in (("observed_at", self.observed_at), ("validated_at", self.validated_at)):
            if value.tzinfo is None or value.utcoffset() is None:
                raise WNF7ContractError(f"{name} must include a timezone")
        if self.validated_at < self.observed_at:
            raise WNF7ContractError("validated_at cannot precede observed_at")
        if (
            self.validation_status is EvidenceValidationStatus.VALIDATED
            and self.freshness_status
            not in {EvidenceFreshness.CURRENT, EvidenceFreshness.NOT_APPLICABLE}
        ):
            raise WNF7ContractError("validated evidence must be current or not applicable")
        object.__setattr__(
            self,
            "rationale_summary",
            _text("rationale_summary", self.rationale_summary),
        )
        object.__setattr__(self, "metadata", _safe_metadata(self.metadata))

    def to_evidence_values(self, candidate_evidence_id: UUID | str) -> dict[str, Any]:
        candidate_id = _uuid("candidate_evidence_id", str(candidate_evidence_id))
        return {
            "scenario_code": self.scenario_code,
            "evidence_ref": self.validation_evidence_ref,
            "source_system": self.source_system,
            "content_sha256": self.content_sha256,
            "freshness_status": self.freshness_status.value,
            "validation_status": self.validation_status.value,
            "observed_at": self.observed_at.astimezone(timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "validated_at": self.validated_at.astimezone(timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "validated_by": str(self.validated_by),
            "validated_by_role_code": self.validated_by_role_code.value,
            "candidate_evidence_id": str(candidate_id),
            "metadata": {
                **dict(self.metadata),
                "pilot_code": self.pilot_code,
                "candidate_evidence_ref": self.candidate_evidence_ref,
                "rationale_summary": self.rationale_summary,
                "production_authorized": False,
                "authority_posture": "DOES_NOT_CONFER_AUTHORITY",
            },
        }


def parse_evidence_validation(payload: Mapping[str, Any]) -> EvidenceValidationSubmission:
    if not isinstance(payload, Mapping):
        raise WNF7ContractError("evidence validation must be an object")
    _strict_payload(
        "evidence validation",
        payload,
        allowed=_EVIDENCE_FIELDS,
        required=_REQUIRED_EVIDENCE_FIELDS,
    )
    try:
        freshness = EvidenceFreshness(_text("freshness_status", payload["freshness_status"]))
        validation = EvidenceValidationStatus(
            _text("validation_status", payload["validation_status"])
        )
        role = ReviewerRole(_text("validated_by_role_code", payload["validated_by_role_code"]))
    except ValueError as exc:
        raise WNF7ContractError("evidence validation contains a non-canonical state") from exc
    return EvidenceValidationSubmission(
        pilot_code=_text("pilot_code", payload["pilot_code"]),
        scenario_code=_scenario_code(payload["scenario_code"]),
        candidate_evidence_ref=_controlled_ref(
            "candidate_evidence_ref", payload["candidate_evidence_ref"]
        ),
        validation_evidence_ref=_controlled_ref(
            "validation_evidence_ref", payload["validation_evidence_ref"]
        ),
        source_system=_text("source_system", payload["source_system"]),
        content_sha256=_sha256(payload["content_sha256"]),
        freshness_status=freshness,
        validation_status=validation,
        observed_at=_timestamp("observed_at", payload["observed_at"]),
        validated_at=_timestamp("validated_at", payload["validated_at"]),
        validated_by=_uuid("validated_by", payload["validated_by"]),
        validated_by_role_code=role,
        rationale_summary=_text("rationale_summary", payload["rationale_summary"]),
        metadata=_safe_metadata(payload.get("metadata", {})),
    )


@dataclass(frozen=True, slots=True)
class AdjudicationDecisionSubmission:
    scenario_code: str
    reviewer_subject_id: UUID
    reviewer_role_code: ReviewerRole
    disposition: DecisionDisposition
    decision_status: AdjudicationStatus
    rationale_summary: str
    decided_at: datetime
    evidence_refs: tuple[str, ...]
    automated_result_ref: str
    attestation_ref: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    pilot_code: str = "PILOT-7D-001"

    def __post_init__(self) -> None:
        if self.pilot_code != "PILOT-7D-001":
            raise WNF7ContractError("adjudication is restricted to PILOT-7D-001")
        object.__setattr__(self, "scenario_code", _scenario_code(self.scenario_code))
        object.__setattr__(
            self,
            "reviewer_subject_id",
            _uuid("reviewer_subject_id", str(self.reviewer_subject_id)),
        )
        try:
            object.__setattr__(self, "reviewer_role_code", ReviewerRole(self.reviewer_role_code))
            object.__setattr__(self, "disposition", DecisionDisposition(self.disposition))
            object.__setattr__(self, "decision_status", AdjudicationStatus(self.decision_status))
        except ValueError as exc:
            raise WNF7ContractError("adjudication contains a non-canonical state") from exc
        object.__setattr__(
            self,
            "rationale_summary",
            _text("rationale_summary", self.rationale_summary),
        )
        if not isinstance(self.decided_at, datetime):
            raise WNF7ContractError("decided_at must be a datetime")
        if self.decided_at.tzinfo is None or self.decided_at.utcoffset() is None:
            raise WNF7ContractError("decided_at must include a timezone")
        if isinstance(self.evidence_refs, (str, bytes)) or not isinstance(
            self.evidence_refs, Sequence
        ):
            raise WNF7ContractError("evidence_refs must be an array")
        refs = tuple(_controlled_ref("evidence_refs", value) for value in self.evidence_refs)
        if not refs or len(refs) != len(set(refs)):
            raise WNF7ContractError("adjudication requires unique evidence references")
        object.__setattr__(self, "evidence_refs", refs)
        object.__setattr__(
            self,
            "automated_result_ref",
            _controlled_ref("automated_result_ref", self.automated_result_ref),
        )
        if self.attestation_ref is not None:
            object.__setattr__(
                self,
                "attestation_ref",
                _controlled_ref("attestation_ref", self.attestation_ref),
            )
        if self.decision_status is AdjudicationStatus.COMPLETE and self.attestation_ref is None:
            raise WNF7ContractError("completed adjudication requires an attestation reference")
        object.__setattr__(self, "metadata", _safe_metadata(self.metadata))

    def to_decision_values(self) -> dict[str, Any]:
        return {
            "scenario_code": self.scenario_code,
            "reviewer_subject_id": str(self.reviewer_subject_id),
            "reviewer_role_code": self.reviewer_role_code.value,
            "disposition": self.disposition.value,
            "decision_status": self.decision_status.value,
            "rationale_summary": self.rationale_summary,
            "attestation_ref": self.attestation_ref,
            "decided_at": self.decided_at.astimezone(timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "metadata": {
                **dict(self.metadata),
                "pilot_code": self.pilot_code,
                "evidence_refs": list(self.evidence_refs),
                "automated_result_ref": self.automated_result_ref,
                "production_authorized": False,
                "authority_posture": "DOES_NOT_CONFER_AUTHORITY",
            },
        }


def parse_adjudication_decision(payload: Mapping[str, Any]) -> AdjudicationDecisionSubmission:
    if not isinstance(payload, Mapping):
        raise WNF7ContractError("adjudication must be an object")
    _strict_payload(
        "adjudication",
        payload,
        allowed=_DECISION_FIELDS,
        required=_REQUIRED_DECISION_FIELDS,
    )
    raw_refs = payload["evidence_refs"]
    if isinstance(raw_refs, (str, bytes)) or not isinstance(raw_refs, Sequence):
        raise WNF7ContractError("evidence_refs must be an array")
    try:
        role = ReviewerRole(_text("reviewer_role_code", payload["reviewer_role_code"]))
        disposition = DecisionDisposition(_text("disposition", payload["disposition"]))
        status = AdjudicationStatus(_text("decision_status", payload["decision_status"]))
    except ValueError as exc:
        raise WNF7ContractError("adjudication contains a non-canonical state") from exc
    return AdjudicationDecisionSubmission(
        pilot_code=_text("pilot_code", payload["pilot_code"]),
        scenario_code=_scenario_code(payload["scenario_code"]),
        reviewer_subject_id=_uuid("reviewer_subject_id", payload["reviewer_subject_id"]),
        reviewer_role_code=role,
        disposition=disposition,
        decision_status=status,
        rationale_summary=_text("rationale_summary", payload["rationale_summary"]),
        attestation_ref=(
            _controlled_ref("attestation_ref", payload["attestation_ref"])
            if payload.get("attestation_ref") is not None
            else None
        ),
        decided_at=_timestamp("decided_at", payload["decided_at"]),
        evidence_refs=tuple(_controlled_ref("evidence_refs", value) for value in raw_refs),
        automated_result_ref=_controlled_ref(
            "automated_result_ref", payload["automated_result_ref"]
        ),
        metadata=_safe_metadata(payload.get("metadata", {})),
    )
