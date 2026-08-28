from uuid import uuid4

import pytest

from setc.fashion.service import FashionContractError
from setc.fashion.supabase_repository import SupabaseFashionRepository


class Result:
    def __init__(self, data):
        self.data = data


class Query:
    def __init__(self, client, table):
        self.client = client
        self.table_name = table
        self.operation = None
        self.payload = None
        self.filters = []

    def select(self, columns="*"):
        self.operation = ("select", columns)
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def insert(self, payload):
        self.operation = ("insert", None)
        self.payload = dict(payload)
        return self

    def update(self, payload):
        self.operation = ("update", None)
        self.payload = dict(payload)
        return self

    def execute(self):
        self.client.calls.append((self.client.schema_name, self.table_name, self.operation, self.payload, self.filters))
        if self.operation[0] == "select":
            return Result([])
        record = {"id": str(uuid4()), **(self.payload or {})}
        return Result([record])


class Schema:
    def __init__(self, client):
        self.client = client

    def table(self, name):
        return Query(self.client, name)


class FakeClient:
    def __init__(self):
        self.calls = []
        self.schema_name = None

    def schema(self, name):
        self.schema_name = name
        return Schema(self)


def audit():
    return {"request_id": str(uuid4()), "subject": "test", "domain": "fashion"}


def test_adapter_is_pinned_to_fashion_schema():
    client = FakeClient()
    SupabaseFashionRepository(client)
    assert client.schema_name == "fashion"


def test_adapter_rejects_external_authority_table_names():
    repo = SupabaseFashionRepository(FakeClient())
    for resource in ("transactions", "settlement_requests", "rights_interests", "organizations", "shipments"):
        with pytest.raises(FashionContractError):
            repo.list(resource)


def test_lifecycle_is_insert_only():
    client = FakeClient()
    repo = SupabaseFashionRepository(client)
    instance_id = uuid4()
    repo.append_lifecycle_event(instance_id, {"event_type": "repair", "occurred_at": "2026-08-28T00:00:00Z"}, audit=audit())
    call = client.calls[-1]
    assert call[0] == "fashion"
    assert call[1] == "circular_lifecycle_events"
    assert call[2][0] == "insert"
    assert call[3]["product_instance_id"] == str(instance_id)
    assert "application_audit" in call[3]["metadata"]


def test_registry_create_carries_audit_in_provenance():
    client = FakeClient()
    repo = SupabaseFashionRepository(client)
    repo.create("brands", {"brand_code": "B-1", "display_name": "Brand"}, audit=audit())
    payload = client.calls[-1][3]
    assert "application_audit" in payload["provenance"]


def test_evidence_verification_only_updates_verification_state():
    client = FakeClient()
    repo = SupabaseFashionRepository(client)
    evidence_id = uuid4()
    repo.verify_evidence_link(evidence_id, "verified", audit=audit())
    call = client.calls[-1]
    assert call[1] == "reflex_evidence_links"
    assert call[2][0] == "update"
    assert call[3] == {"verification_state": "verified"}
    assert call[4] == [("id", str(evidence_id))]


def test_adapter_has_no_delete_surface():
    assert not hasattr(SupabaseFashionRepository, "delete")
    assert not hasattr(SupabaseFashionRepository, "delete_lifecycle_event")
