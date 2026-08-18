"""Bounded software/runtime observability primitives for SETC Organizations."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Mapping


class HealthStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


class DiagnosticSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


@dataclass(frozen=True)
class DiagnosticEvent:
    component: str
    code: str
    severity: DiagnosticSeverity
    message: str
    observed_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    details: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.component.strip():
            raise ValueError("component is required")
        if not self.code.strip():
            raise ValueError("code is required")
        if not self.message.strip():
            raise ValueError("message is required")
        if self.observed_at.tzinfo is None:
            raise ValueError("observed_at must be timezone-aware")

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component.strip(),
            "code": self.code.strip(),
            "severity": self.severity.value,
            "message": self.message.strip(),
            "observed_at": self.observed_at.isoformat(),
            "details": dict(self.details),
        }


@dataclass(frozen=True)
class HealthSnapshot:
    component: str
    status: HealthStatus
    ready: bool
    diagnostics: tuple[DiagnosticEvent, ...] = ()

    def __post_init__(self) -> None:
        if not self.component.strip():
            raise ValueError("component is required")
        if self.status is HealthStatus.UNHEALTHY and self.ready:
            raise ValueError("an unhealthy component cannot be ready")

    @property
    def degraded(self) -> bool:
        return self.status is HealthStatus.DEGRADED

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component.strip(),
            "status": self.status.value,
            "ready": self.ready,
            "degraded": self.degraded,
            "diagnostics": [event.to_dict() for event in self.diagnostics],
        }
