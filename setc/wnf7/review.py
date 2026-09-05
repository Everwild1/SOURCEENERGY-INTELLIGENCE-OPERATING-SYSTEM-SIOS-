"""Strict human-review mobilization contracts for the WNF-7 pilot.

The parser prepares accountable reviewer appointment data for a trusted server
workflow.  It does not appoint a reviewer, advance a release gate, authorize
production, or provide an execution path.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import StrEnum
from typing import Any
from uuid import UUID

from .models import WNF7ContractError


class ReviewerRole(StrEnum):
    QA_LEAD = "QA_LEAD"
    TECH_AUTHORITY = "TECH_AUTHORITY"
    SETC_OWNER = "SETC_OWNER"
    SOURCECUBE_OWNER = "SOURCECUBE_OWNER"
    PILOT_OWNER = "PILOT_OWNER"
    KNOWLEDGE_GOVERNOR = "KNOWLEDGE_GOVERNOR"


class ReviewerConflictStatus(StrEnum):
    PENDING = "PENDING"
    NO_CONFLICT_DECLARED = "NO_CONFLICT_DECLARED"
    CONFLICT_DECLARED = "CONFLICT_DECLARED"
    RECUSED = "RECUSED"


class ReviewerMobilizationStatus(StrEnum):
    NOMINATED = "NOMINATED"
    ASSIGNED = "ASSIGNED"
    ACCEPTED = "ACCEPTED"
    HOLD = "HOLD"


_FIELDS = frozenset(
    {
        "pilot_code",
        "reviewer_role_code",
        "reviewer_subject_id",
        "reviewer_display_ref",
        "appointment_evidence_ref",
        "appointed_by_subject_id",
        "conflict_status",
        "mobilization_status",
        "effective_at",
        "accepted_at",
        "metadata",
    }
)
_REQUIRED_FIELDS = _FIELDS - {"accepted_at", "metadata"}
_SENSITIVE_KEY_PARTS = (
    "password",
    "secret",
    "private_key",
    "api_key",
    "service_role",
    "access_token",
    "refresh_token",
)


def _text(name: str, value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise WNF7ContractError(f"{name} must be a non-empty string")
    return value.strip()


def _uuid(name: str, value: Any) -> UUID:
    raw = _text(name, value)
    try:
        return UUID(raw)
    except ValueError as exc:
        raise WNF7ContractError(f"{name} must be a UUID") from exc


def _timestamp(name: str, value: Any) -> datetime:
    raw = _text(name, value)
    try:
        parsed = datetime.fromisoformat(raw[:-1] + "+00:00" if raw.endswith("Z") else raw)
    except ValueError as exc:
        raise WNF7ContractError(f"{name} must be an ISO 8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise WNF7ContractError(f"{name} must include a timezone")
    return parsed


def _controlled_ref(name: str, value: Any) -> str:
    reference = _text(name, value)
    if not reference.startswith("controlled://"):
        raise WNF7ContractError(f"{name} must use a controlled:// reference")
    return reference


def _safe_metadata(value: Any) -> dict[str, Any]:
    if not isinstance(value, Mapping):
        raise WNF7ContractError("metadata must be an object")
    metadata = dict(value)
    stack: list[Any] = [metadata]
    while stack:
        item = stack.pop()
        if isinstance(item, Mapping):
            for key, child in item.items():
                if not isinstance(key, str):
                    raise WNF7ContractError("metadata keys must be strings")
                lowered = key.lower()
                if any(part in lowered for part in _SENSITIVE_KEY_PARTS):
                    raise WNF7ContractError("metadata cannot contain secret-bearing fields")
                stack.append(child)
        elif isinstance(item, (list, tuple)):
            stack.extend(item)
    return metadata


@dataclass(frozen=True, slots=True)
class ReviewerAppointmentSubmission:
    reviewer_role_code: ReviewerRole
    reviewer_subject_id: UUID
    reviewer_display_ref: str
    appointment_evidence_ref: str
    appointed_by_subject_id: UUID
    conflict_status: ReviewerConflictStatus
    mobilization_status: ReviewerMobilizationStatus
    effective_at: datetime
    accepted_at: datetime | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    pilot_code: str = "PILOT-7D-001"

    def __post_init__(self) -> None:
        try:
            object.__setattr__(self, "reviewer_role_code", ReviewerRole(self.reviewer_role_code))
            object.__setattr__(self, "conflict_status", ReviewerConflictStatus(self.conflict_status))
            object.__setattr__(
                self,
                "mobilization_status",
                ReviewerMobilizationStatus(self.mobilization_status),
            )
        except ValueError as exc:
            raise WNF7ContractError("reviewer appointment contains a non-canonical state") from exc
        object.__setattr__(
            self,
            "reviewer_subject_id",
            _uuid("reviewer_subject_id", str(self.reviewer_subject_id)),
        )
        object.__setattr__(
            self,
            "appointed_by_subject_id",
            _uuid("appointed_by_subject_id", str(self.appointed_by_subject_id)),
        )
        object.__setattr__(
            self,
            "reviewer_display_ref",
            _controlled_ref("reviewer_display_ref", self.reviewer_display_ref),
        )
        object.__setattr__(
            self,
            "appointment_evidence_ref",
            _controlled_ref("appointment_evidence_ref", self.appointment_evidence_ref),
        )
        if not isinstance(self.effective_at, datetime):
            raise WNF7ContractError("effective_at must be a datetime")
        if self.accepted_at is not None and not isinstance(self.accepted_at, datetime):
            raise WNF7ContractError("accepted_at must be a datetime")
        if self.pilot_code != "PILOT-7D-001":
            raise WNF7ContractError("reviewer appointment is restricted to PILOT-7D-001")
        if self.reviewer_subject_id == self.appointed_by_subject_id:
            raise WNF7ContractError("a reviewer cannot appoint themself")
        if self.effective_at.tzinfo is None or self.effective_at.utcoffset() is None:
            raise WNF7ContractError("effective_at must include a timezone")
        if self.accepted_at is not None:
            if self.accepted_at.tzinfo is None or self.accepted_at.utcoffset() is None:
                raise WNF7ContractError("accepted_at must include a timezone")
            if self.accepted_at < self.effective_at:
                raise WNF7ContractError("accepted_at cannot precede effective_at")
        if self.mobilization_status is ReviewerMobilizationStatus.ACCEPTED:
            if self.conflict_status is not ReviewerConflictStatus.NO_CONFLICT_DECLARED:
                raise WNF7ContractError("acceptance requires a no-conflict declaration")
            if self.accepted_at is None:
                raise WNF7ContractError("acceptance requires accepted_at")
        elif self.accepted_at is not None:
            raise WNF7ContractError("accepted_at is only valid for an accepted appointment")
        if self.conflict_status in {
            ReviewerConflictStatus.CONFLICT_DECLARED,
            ReviewerConflictStatus.RECUSED,
        } and self.mobilization_status is not ReviewerMobilizationStatus.HOLD:
            raise WNF7ContractError("a conflict or recusal requires HOLD")
        object.__setattr__(self, "metadata", _safe_metadata(self.metadata))

    def to_assignment_values(self) -> dict[str, Any]:
        """Return current-state values for a trusted persistence adapter."""

        return {
            "pilot_code": self.pilot_code,
            "reviewer_role_code": self.reviewer_role_code.value,
            "reviewer_subject_id": str(self.reviewer_subject_id),
            "reviewer_display_ref": self.reviewer_display_ref,
            "appointment_evidence_ref": self.appointment_evidence_ref,
            "conflict_status": self.conflict_status.value,
            "mobilization_status": self.mobilization_status.value,
            "accepted_at": (
                self.accepted_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
                if self.accepted_at
                else None
            ),
            "metadata": {
                **dict(self.metadata),
                "appointed_by_subject_id": str(self.appointed_by_subject_id),
                "effective_at": self.effective_at.astimezone(timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "production_authorized": False,
                "authority_posture": "DOES_NOT_CONFER_AUTHORITY",
            },
        }


def parse_reviewer_appointment(payload: Mapping[str, Any]) -> ReviewerAppointmentSubmission:
    """Parse a strict reviewer nomination, assignment, acceptance, or hold packet."""

    if not isinstance(payload, Mapping):
        raise WNF7ContractError("reviewer appointment must be an object")
    unknown = sorted(set(payload) - _FIELDS)
    if unknown:
        raise WNF7ContractError(
            f"reviewer appointment contains prohibited fields: {', '.join(unknown)}"
        )
    missing = sorted(_REQUIRED_FIELDS - set(payload))
    if missing:
        raise WNF7ContractError(
            f"reviewer appointment is missing required fields: {', '.join(missing)}"
        )
    try:
        role = ReviewerRole(_text("reviewer_role_code", payload["reviewer_role_code"]))
        conflict = ReviewerConflictStatus(
            _text("conflict_status", payload["conflict_status"])
        )
        status = ReviewerMobilizationStatus(
            _text("mobilization_status", payload["mobilization_status"])
        )
    except ValueError as exc:
        raise WNF7ContractError("reviewer appointment contains a non-canonical state") from exc
    return ReviewerAppointmentSubmission(
        pilot_code=_text("pilot_code", payload["pilot_code"]),
        reviewer_role_code=role,
        reviewer_subject_id=_uuid("reviewer_subject_id", payload["reviewer_subject_id"]),
        reviewer_display_ref=_controlled_ref(
            "reviewer_display_ref", payload["reviewer_display_ref"]
        ),
        appointment_evidence_ref=_controlled_ref(
            "appointment_evidence_ref", payload["appointment_evidence_ref"]
        ),
        appointed_by_subject_id=_uuid(
            "appointed_by_subject_id", payload["appointed_by_subject_id"]
        ),
        conflict_status=conflict,
        mobilization_status=status,
        effective_at=_timestamp("effective_at", payload["effective_at"]),
        accepted_at=(
            _timestamp("accepted_at", payload["accepted_at"])
            if payload.get("accepted_at") is not None
            else None
        ),
        metadata=_safe_metadata(payload.get("metadata", {})),
    )
