"""Typed institutional relationship graph primitives governed by SETC-117."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from setc.core import SETCIdentifier


class RelationshipType(StrEnum):
    OPERATES = "OPERATES"
    OWNS = "OWNS"
    CONTROLS = "CONTROLS"
    MANAGES = "MANAGES"
    FUNDS = "FUNDS"
    GRANTS_TO = "GRANTS_TO"
    INVESTS_IN = "INVESTS_IN"
    LENDS_TO = "LENDS_TO"
    GUARANTEES = "GUARANTEES"
    SPONSORS = "SPONSORS"
    PARTNERS_WITH = "PARTNERS_WITH"
    AFFILIATED_WITH = "AFFILIATED_WITH"
    MEMBER_OF = "MEMBER_OF"
    VERIFIED_BY = "VERIFIED_BY"
    ACCREDITED_BY = "ACCREDITED_BY"
    RESEARCHES_WITH = "RESEARCHES_WITH"
    LICENSES_FROM = "LICENSES_FROM"
    LICENSES_TO = "LICENSES_TO"
    COMMERCIALIZES = "COMMERCIALIZES"
    INCUBATES = "INCUBATES"
    ACCELERATES = "ACCELERATES"
    MENTORS = "MENTORS"
    SUPPORTS = "SUPPORTS"
    CONTRACTS_WITH = "CONTRACTS_WITH"
    PROCURES_FROM = "PROCURES_FROM"
    SUPPLIES_TO = "SUPPLIES_TO"
    REFERS_TO = "REFERS_TO"
    PARTICIPATES_IN = "PARTICIPATES_IN"
    GOVERNED_BY = "GOVERNED_BY"


class RelationshipState(StrEnum):
    PROPOSED = "PROPOSED"
    ASSERTED = "ASSERTED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    VERIFIED = "VERIFIED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    DISPUTED = "DISPUTED"
    EXPIRED = "EXPIRED"
    TERMINATED = "TERMINATED"
    REVOKED = "REVOKED"
    ARCHIVED = "ARCHIVED"


_SYMMETRIC_TYPES = {
    RelationshipType.PARTNERS_WITH,
    RelationshipType.AFFILIATED_WITH,
    RelationshipType.RESEARCHES_WITH,
    RelationshipType.CONTRACTS_WITH,
}

_INVERSE_TYPES: dict[RelationshipType, RelationshipType] = {
    RelationshipType.LICENSES_FROM: RelationshipType.LICENSES_TO,
    RelationshipType.LICENSES_TO: RelationshipType.LICENSES_FROM,
    RelationshipType.PROCURES_FROM: RelationshipType.SUPPLIES_TO,
    RelationshipType.SUPPLIES_TO: RelationshipType.PROCURES_FROM,
}


@dataclass(frozen=True, slots=True)
class OrganizationRelationship:
    """A governed relationship between two canonical SETC organizations."""

    relationship_id: SETCIdentifier
    source_organization_id: SETCIdentifier
    target_organization_id: SETCIdentifier
    relationship_type: RelationshipType
    state: RelationshipState = RelationshipState.ASSERTED
    effective_from: datetime | None = None
    effective_to: datetime | None = None
    evidence_reference: str | None = None
    asserted_by: str | None = None

    def __post_init__(self) -> None:
        if self.source_organization_id == self.target_organization_id:
            raise ValueError("relationship source and target must differ")
        if self.effective_from and self.effective_to and self.effective_to < self.effective_from:
            raise ValueError("relationship effective_to cannot precede effective_from")
        if self.evidence_reference is not None and not self.evidence_reference.strip():
            raise ValueError("evidence_reference cannot be blank")
        if self.asserted_by is not None and not self.asserted_by.strip():
            raise ValueError("asserted_by cannot be blank")

    @property
    def is_symmetric(self) -> bool:
        return self.relationship_type in _SYMMETRIC_TYPES

    @property
    def inverse_type(self) -> RelationshipType | None:
        if self.is_symmetric:
            return self.relationship_type
        return _INVERSE_TYPES.get(self.relationship_type)

    def inverse(self) -> "OrganizationRelationship":
        inverse_type = self.inverse_type
        if inverse_type is None:
            raise ValueError(f"{self.relationship_type} has no governed inverse")
        return OrganizationRelationship(
            relationship_id=self.relationship_id,
            source_organization_id=self.target_organization_id,
            target_organization_id=self.source_organization_id,
            relationship_type=inverse_type,
            state=self.state,
            effective_from=self.effective_from,
            effective_to=self.effective_to,
            evidence_reference=self.evidence_reference,
            asserted_by=self.asserted_by,
        )
