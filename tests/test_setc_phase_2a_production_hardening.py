"""Phase II-A production-hardening regression gates for SETC Organizations."""

import pytest

import setc.organizations as organizations
from setc.core import SETCIdentifier, new_setc_oid
from setc.organizations import Organization, OrganizationCapability, OrganizationType


def test_setc_identifier_rejects_noncanonical_values():
    invalid_values = (
        "",
        "SETC-OID-",
        "setc-oid-00000000000000000000000000000000",
        "SETC-OID-not-a-uuid",
        "SETC-OID-0000000000000000000000000000000g",
    )
    for value in invalid_values:
        with pytest.raises(ValueError):
            SETCIdentifier(value)


def test_minted_identifier_round_trips_through_string_form():
    oid = new_setc_oid()
    assert SETCIdentifier(str(oid)) == oid


def test_organization_rejects_blank_legal_name():
    with pytest.raises(ValueError):
        Organization(
            oid=new_setc_oid(),
            legal_name="   ",
            organization_type=OrganizationType.OTHER,
        )


def test_organization_normalizes_legal_name_and_aliases():
    organization = Organization(
        oid=new_setc_oid(),
        legal_name="  Example Research Institute  ",
        organization_type=OrganizationType.RESEARCH_INSTITUTION,
        capabilities={OrganizationCapability.RESEARCHES},
        aliases={"  ERI  ", "", "   ", "Example RI"},
    )
    assert organization.legal_name == "Example Research Institute"
    assert organization.aliases == {"ERI", "Example RI"}


def test_representative_public_api_symbols_are_stable():
    expected = {
        "Organization",
        "OrganizationType",
        "OrganizationCapability",
        "InstitutionalIdentity",
        "InstitutionalPolicy",
        "InstitutionalRisk",
        "ComplianceMandate",
        "AdjudicativeProceeding",
        "InstitutionalJudgment",
        "AssuranceEngagement",
    }
    assert expected.issubset(set(organizations.__all__))
    for symbol in expected:
        assert getattr(organizations, symbol) is not None


def test_public_api_has_no_private_or_duplicate_exports():
    assert len(organizations.__all__) == len(set(organizations.__all__))
    assert all(not symbol.startswith("_") for symbol in organizations.__all__)
