"""SourceEnergy Ecology Block cross-domain orchestration contracts.

This package models references and orchestration semantics only. It does not
transfer institutional, legal, financial, settlement, ledger, custody, IP,
logistics, procurement or fiduciary authority from source domains.
"""

from .domain import (
    AuthorityPosture,
    EcologyCorrelation,
    EcologyDomain,
    EcologyObjectReference,
    EvidenceReference,
    SetcOrganizationId,
)

__all__ = [
    "AuthorityPosture",
    "EcologyCorrelation",
    "EcologyDomain",
    "EcologyObjectReference",
    "EvidenceReference",
    "SetcOrganizationId",
]
