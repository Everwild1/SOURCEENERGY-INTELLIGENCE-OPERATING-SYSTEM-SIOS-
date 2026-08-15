"""Stable identifier helpers for canonical SETC domain objects."""

from __future__ import annotations

from dataclasses import dataclass
import re
from uuid import UUID, uuid4

_OID_RE = re.compile(r"^SETC-OID-([0-9a-f]{32})$")


@dataclass(frozen=True, slots=True)
class SETCIdentifier:
    """Validated canonical SETC identifier."""

    value: str

    def __post_init__(self) -> None:
        match = _OID_RE.fullmatch(self.value)
        if not match:
            raise ValueError("invalid SETC organization identifier")
        UUID(hex=match.group(1))

    def __str__(self) -> str:
        return self.value


def new_setc_oid() -> SETCIdentifier:
    """Mint a new opaque organization identifier without business semantics."""

    return SETCIdentifier(f"SETC-OID-{uuid4().hex}")
