from __future__ import annotations

import pytest

from setc.core import SETCIdentifier
from setc.organizations.readied_companies import (
    CompanyReadinessGate,
    CompanyReadinessProfile,
    DefinitionState,
    OpportunityAuthorityState,
    PeopleFitRecord,
    PeopleFitState,
    ReadinessDefinition,
)


def oid(seed: str) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{seed * 32}")


def definition(state: DefinitionState) -> ReadinessDefinition:
    kwargs = {}
    if state is DefinitionState.VERIFIED:
        kwargs = {
            "evidence_references": ("evidence:verified",),
            "owner_reference": "owner:accountable",
        }
    return ReadinessDefinition("A specific, governed definition.", state, **kwargs)


def confirmed_people_fit() -> PeopleFitRecord:
    return PeopleFitRecord(
        state=PeopleFitState.CONFIRMED,
        role_blueprint_reference="blueprint:v1",
        primary_team_references=("person:primary",),
        alternate_team_references=("person:alternate",),
        consent_evidence_references=("evidence:consent",),
        availability_evidence_references=("evidence:availability",),
        credential_evidence_references=("evidence:credentials",),
        conflict_review_reference="review:conflict",
        workshare_review_reference="review:workshare",
        reviewer_reference="reviewer:authorized",
    )


def profile(
    definition_state: DefinitionState,
    people_fit: PeopleFitRecord | None = None,
) -> CompanyReadinessProfile:
    return CompanyReadinessProfile(
        profile_id=oid("1"),
        organization_id=oid("2"),
        purpose=definition(definition_state),
        product=definition(definition_state),
        profitability=definition(definition_state),
        people_fit=people_fit or PeopleFitRecord(),
    )


def test_draft_ppp_is_people_fit_pending() -> None:
    item = profile(DefinitionState.DRAFT_DEFINED)

    assert item.readiness_gate is CompanyReadinessGate.PEOPLE_FIT_PENDING
    assert item.opportunity_authority is OpportunityAuthorityState.WITHHELD
    assert item.may_enter_opportunity_review() is False


def test_verified_ppp_and_confirmed_people_fit_enters_opportunity_review() -> None:
    item = profile(DefinitionState.VERIFIED, confirmed_people_fit())

    assert item.readiness_gate is CompanyReadinessGate.READY_FOR_OPPORTUNITY_GATE
    assert item.may_enter_opportunity_review() is True
    assert item.opportunity_authority is OpportunityAuthorityState.WITHHELD


def test_missing_definition_requires_foundation_remediation() -> None:
    item = profile(DefinitionState.NOT_STARTED)

    assert item.readiness_gate is CompanyReadinessGate.FOUNDATION_REMEDIATION


def test_verified_definition_requires_evidence_and_owner() -> None:
    with pytest.raises(ValueError, match="require evidence"):
        ReadinessDefinition("Defined", DefinitionState.VERIFIED)


def test_confirmed_people_fit_requires_full_evidence_stack() -> None:
    with pytest.raises(ValueError, match="confirmed people fit requires"):
        PeopleFitRecord(state=PeopleFitState.CONFIRMED)
