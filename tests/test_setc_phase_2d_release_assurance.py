"""Phase II-D release-assurance regression gates."""

import time

import pytest

from setc.core import SETCIdentifier, new_setc_oid
from setc.release_assurance import (
    COMPLETED_WORKSTREAMS,
    REQUIRED_RELEASE_GATES,
    ReleaseAssuranceManifest,
    verify_release_gate_evidence,
)


def test_release_manifest_is_machine_readable_and_tracks_phase_ii_lineage():
    manifest = ReleaseAssuranceManifest()
    payload = manifest.to_dict()
    assert payload["schema_version"] == "1.0"
    assert payload["phase"] == "II"
    assert payload["completed_workstreams"] == list(COMPLETED_WORKSTREAMS)
    assert payload["required_gates"] == list(REQUIRED_RELEASE_GATES)


def test_release_manifest_rejects_lineage_or_schema_drift():
    with pytest.raises(ValueError):
        ReleaseAssuranceManifest(schema_version="2.0")
    with pytest.raises(ValueError):
        ReleaseAssuranceManifest(completed_workstreams=("II-A",))


def test_release_gate_evidence_fails_closed_when_incomplete():
    manifest = ReleaseAssuranceManifest()
    with pytest.raises(ValueError, match="missing release gate evidence"):
        verify_release_gate_evidence(manifest, {"setc-core-ci"})


def test_release_gate_evidence_accepts_complete_gate_set():
    manifest = ReleaseAssuranceManifest()
    verify_release_gate_evidence(manifest, set(REQUIRED_RELEASE_GATES))


def test_identifier_round_trip_has_lightweight_engineering_baseline():
    # Engineering regression threshold only; this is not an SLA or service guarantee.
    iterations = 1000
    started = time.perf_counter()
    for _ in range(iterations):
        oid = new_setc_oid()
        assert SETCIdentifier(str(oid)) == oid
    elapsed = time.perf_counter() - started
    assert elapsed < 2.0
