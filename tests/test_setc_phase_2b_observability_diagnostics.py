"""Regression tests for bounded SETC runtime observability contracts."""

from datetime import datetime, timezone

import pytest

from setc.organizations.observability import (
    DiagnosticEvent,
    DiagnosticSeverity,
    HealthSnapshot,
    HealthStatus,
)


def test_diagnostic_event_is_machine_readable():
    event = DiagnosticEvent(
        component="setc.organizations",
        code="ORG_IMPORT_OK",
        severity=DiagnosticSeverity.INFO,
        message="Organizations package imported successfully",
        observed_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        details={"modules": 8},
    )
    assert event.to_dict() == {
        "component": "setc.organizations",
        "code": "ORG_IMPORT_OK",
        "severity": "info",
        "message": "Organizations package imported successfully",
        "observed_at": "2026-01-01T00:00:00+00:00",
        "details": {"modules": 8},
    }


def test_diagnostic_event_requires_bounded_identity_fields():
    with pytest.raises(ValueError):
        DiagnosticEvent(" ", "CODE", DiagnosticSeverity.ERROR, "failure")
    with pytest.raises(ValueError):
        DiagnosticEvent("component", " ", DiagnosticSeverity.ERROR, "failure")
    with pytest.raises(ValueError):
        DiagnosticEvent("component", "CODE", DiagnosticSeverity.ERROR, " ")


def test_diagnostic_event_requires_timezone_aware_timestamp():
    with pytest.raises(ValueError):
        DiagnosticEvent(
            "component",
            "CODE",
            DiagnosticSeverity.WARNING,
            "degraded",
            observed_at=datetime(2026, 1, 1),
        )


def test_unhealthy_component_cannot_be_ready():
    with pytest.raises(ValueError):
        HealthSnapshot("setc.organizations", HealthStatus.UNHEALTHY, ready=True)


def test_degraded_component_is_explicit_and_serializable():
    snapshot = HealthSnapshot(
        "setc.organizations",
        HealthStatus.DEGRADED,
        ready=True,
        diagnostics=(
            DiagnosticEvent(
                "setc.organizations",
                "OPTIONAL_DEPENDENCY_DEGRADED",
                DiagnosticSeverity.WARNING,
                "Optional runtime capability is degraded",
                observed_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            ),
        ),
    )
    payload = snapshot.to_dict()
    assert payload["status"] == "degraded"
    assert payload["ready"] is True
    assert payload["degraded"] is True
    assert payload["diagnostics"][0]["severity"] == "warning"
