"""Server-side Supabase/PostgREST adapter for the WEM Fashion repository port.

The adapter is dependency-injected: it does not read credentials, construct a
Supabase client, or expose service-role material. Callers provide a trusted
server-side client. Table selection is allow-listed and settlement/rights
execution domains are intentionally unreachable through this adapter.
"""

from __future__ import annotations

from typing import Any, Mapping, Protocol
from uuid import UUID

from .service import FashionContractError


class QueryResult(Protocol):
    data: Any


class QueryBuilder(Protocol):
    def select(self, columns: str = "*") -> "QueryBuilder": ...
    def eq(self, column: str, value: Any) -> "QueryBuilder": ...
    def insert(self, payload: Mapping[str, Any]) -> "QueryBuilder": ...
    def update(self, payload: Mapping[str, Any]) -> "QueryBuilder": ...
    def execute(self) -> QueryResult: ...


class SchemaClient(Protocol):
    def table(self, name: str) -> QueryBuilder: ...


class SupabaseLikeClient(Protocol):
    def schema(self, name: str) -> SchemaClient: ...


class SupabaseFashionRepository:
    """FashionRepository implementation for a trusted server-side client."""

    TABLES = {
        "brands": "brands",
        "designs": "designs",
        "collections": "collections",
        "materials": "materials",
        "product_models": "product_models",
        "skus": "skus",
        "production_orders": "production_orders",
        "production_batches": "production_batches",
        "product_instances": "product_instances",
    }

    def __init__(self, client: SupabaseLikeClient) -> None:
        self._fashion = client.schema("fashion")

    @classmethod
    def _table_name(cls, resource: str) -> str:
        try:
            return cls.TABLES[resource]
        except KeyError as exc:
            raise FashionContractError(f"Unsupported Fashion persistence resource: {resource}") from exc

    def get(self, resource: str, resource_id: UUID) -> Mapping[str, Any] | None:
        result = self._fashion.table(self._table_name(resource)).select("*").eq("id", str(resource_id)).execute()
        rows = result.data or []
        return rows[0] if rows else None

    def list(self, resource: str) -> list[Mapping[str, Any]]:
        result = self._fashion.table(self._table_name(resource)).select("*").execute()
        return list(result.data or [])

    def create(self, resource: str, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]:
        record = dict(payload)
        record.setdefault("provenance", {})
        if isinstance(record.get("provenance"), dict):
            record["provenance"] = {**record["provenance"], "application_audit": dict(audit)}
        result = self._fashion.table(self._table_name(resource)).insert(record).execute()
        return self._one(result.data, "create")

    def update(self, resource: str, resource_id: UUID, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]:
        record = dict(payload)
        # Do not overwrite existing provenance implicitly. Request correlation is
        # carried only when a provenance object is explicitly being updated.
        if isinstance(record.get("provenance"), dict):
            record["provenance"] = {**record["provenance"], "application_audit": dict(audit)}
        result = self._fashion.table(self._table_name(resource)).update(record).eq("id", str(resource_id)).execute()
        return self._one(result.data, "update")

    def append_lifecycle_event(self, product_instance_id: UUID, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]:
        record = dict(payload)
        record["product_instance_id"] = str(product_instance_id)
        metadata = record.get("metadata") if isinstance(record.get("metadata"), dict) else {}
        record["metadata"] = {**metadata, "application_audit": dict(audit)}
        result = self._fashion.table("circular_lifecycle_events").insert(record).execute()
        return self._one(result.data, "append lifecycle event")

    def submit_evidence_link(self, payload: Mapping[str, Any], *, audit: Mapping[str, str]) -> Mapping[str, Any]:
        record = dict(payload)
        record.setdefault("verification_state", "unverified")
        # The foundation table has no generic metadata column. Preserve request
        # correlation in evidence_reference only at the caller's explicit value;
        # database audit infrastructure remains authoritative for mutation logs.
        result = self._fashion.table("reflex_evidence_links").insert(record).execute()
        return self._one(result.data, "submit evidence")

    def verify_evidence_link(self, evidence_link_id: UUID, verification_state: str, *, audit: Mapping[str, str]) -> Mapping[str, Any]:
        del audit  # request context belongs in the authoritative audit channel
        result = self._fashion.table("reflex_evidence_links").update({"verification_state": verification_state}).eq("id", str(evidence_link_id)).execute()
        return self._one(result.data, "verify evidence")

    @staticmethod
    def _one(data: Any, operation: str) -> Mapping[str, Any]:
        rows = data or []
        if len(rows) != 1:
            raise FashionContractError(f"Fashion persistence {operation} did not return exactly one record")
        return rows[0]
