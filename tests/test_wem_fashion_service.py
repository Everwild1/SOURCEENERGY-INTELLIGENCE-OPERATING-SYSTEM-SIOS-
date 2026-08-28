from uuid import uuid4

import pytest

from setc.fashion.service import (
    FashionAuthorizationError,
    FashionContractError,
    FashionRequestContext,
    FashionRole,
    FashionService,
)


class FakeRepository:
    def __init__(self):
        self.calls = []

    def list(self, resource):
        self.calls.append(("list", resource))
        return []

    def get(self, resource, resource_id):
        self.calls.append(("get", resource, resource_id))
        return {"id": str(resource_id)}

    def create(self, resource, payload, *, audit):
        self.calls.append(("create", resource, dict(payload), dict(audit)))
        return dict(payload)

    def update(self, resource, resource_id, payload, *, audit):
        self.calls.append(("update", resource, resource_id, dict(payload), dict(audit)))
        return dict(payload)

    def append_lifecycle_event(self, product_instance_id, payload, *, audit):
        self.calls.append(("append", product_instance_id, dict(payload), dict(audit)))
        return dict(payload)

    def submit_evidence_link(self, payload, *, audit):
        self.calls.append(("submit", dict(payload), dict(audit)))
        return dict(payload)

    def verify_evidence_link(self, evidence_link_id, verification_state, *, audit):
        self.calls.append(("verify", evidence_link_id, verification_state, dict(audit)))
        return {"verification_state": verification_state}


def ctx(*roles):
    return FashionRequestContext(subject="test-user", roles=frozenset(roles))


def test_reader_cannot_write():
    service = FashionService(FakeRepository())
    with pytest.raises(FashionAuthorizationError):
        service.create(ctx(FashionRole.READER), "brands", {"display_name": "A"})


def test_editor_cannot_operate_production():
    service = FashionService(FakeRepository())
    with pytest.raises(FashionAuthorizationError):
        service.create(ctx(FashionRole.EDITOR), "production_orders", {"status": "planned"})


def test_lifecycle_recorder_can_only_append_via_service_contract():
    repo = FakeRepository()
    service = FashionService(repo)
    service.append_lifecycle_event(ctx(FashionRole.LIFECYCLE_RECORDER), uuid4(), {"event_type": "repair"})
    assert repo.calls[0][0] == "append"
    with pytest.raises(FashionAuthorizationError):
        service.update(ctx(FashionRole.LIFECYCLE_RECORDER), "product_instances", uuid4(), {"current_lifecycle_state": "repair"})


def test_submitter_cannot_self_verify():
    service = FashionService(FakeRepository())
    with pytest.raises(FashionContractError):
        service.submit_evidence_link(ctx(FashionRole.EVIDENCE_SUBMITTER), {"evidence_reference": "x", "verification_state": "verified"})


def test_verifier_has_separate_control():
    service = FashionService(FakeRepository())
    result = service.verify_evidence_link(ctx(FashionRole.EVIDENCE_VERIFIER), uuid4(), "verified")
    assert result["verification_state"] == "verified"


def test_authority_escalation_fails_closed():
    service = FashionService(FakeRepository())
    with pytest.raises(FashionContractError):
        service.create(ctx(FashionRole.EDITOR), "brands", {"display_name": "A", "settlement_final": True})


def test_governed_write_emits_request_and_subject_audit_context():
    repo = FakeRepository()
    service = FashionService(repo)
    service.create(ctx(FashionRole.EDITOR), "brands", {"display_name": "A"})
    audit = repo.calls[0][-1]
    assert audit["domain"] == "fashion"
    assert audit["subject"] == "test-user"
    assert audit["request_id"]


def test_unknown_resource_fails_closed():
    service = FashionService(FakeRepository())
    with pytest.raises(FashionContractError):
        service.create(ctx(FashionRole.ADMIN), "settlement_requests", {})
