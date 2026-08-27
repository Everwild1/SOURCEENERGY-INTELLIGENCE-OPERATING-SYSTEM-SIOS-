"""Revocation and continuity enforcement for SETC-HB-001."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from .models import HeartBeatAssertion, HeartBeatDecision


class CredentialStatus(StrEnum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class ContinuityContext:
    credential_status: CredentialStatus
    continuity_status: HeartBeatDecision | None
    evaluated_at: datetime


def assert_usable_for_authorization(
    assertion: HeartBeatAssertion,
    context: ContinuityContext,
    *,
    now: datetime,
) -> None:
    """Fail closed before an assertion enters IAM/PDP authorization."""
    if context.credential_status is not CredentialStatus.ACTIVE:
        raise PermissionError("cardiac credential is not active")
    if now >= assertion.expires_at:
        raise PermissionError("HeartBeat assertion has expired")
    if assertion.liveness_status is not HeartBeatDecision.SUCCEEDED:
        raise PermissionError("HeartBeat liveness requirement not satisfied")
    if context.continuity_status in {
        HeartBeatDecision.FAILED,
        HeartBeatDecision.DEGRADED,
        HeartBeatDecision.REVOKED,
    }:
        raise PermissionError("HeartBeat continuity requires re-evaluation")
