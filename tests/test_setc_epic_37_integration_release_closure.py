"""Epic 37 integration and release-closure regression gates for SETC Organizations."""

import importlib

import setc.organizations as organizations


REPRESENTATIVE_PUBLIC_SYMBOLS = (
    "Organization",
    "InstitutionalIdentity",
    "InstitutionalPolicy",
    "InstitutionalRisk",
    "ComplianceMandate",
    "AdjudicativeProceeding",
    "InstitutionalJudgment",
    "AssuranceEngagement",
)

REPRESENTATIVE_MODULES = (
    "setc.organizations.models",
    "setc.organizations.identity_authority",
    "setc.organizations.policy_rules",
    "setc.organizations.risk_controls",
    "setc.organizations.compliance_supervision",
    "setc.organizations.adjudication_due_process",
    "setc.organizations.judgment_execution",
    "setc.organizations.assurance_audit",
)


def test_representative_governance_modules_import_as_one_stack():
    for module_name in REPRESENTATIVE_MODULES:
        assert importlib.import_module(module_name) is not None


def test_representative_governance_symbols_are_publicly_exported():
    for symbol in REPRESENTATIVE_PUBLIC_SYMBOLS:
        assert hasattr(organizations, symbol), symbol
        assert symbol in organizations.__all__, symbol


def test_public_export_registry_contains_no_duplicate_names():
    assert len(organizations.__all__) == len(set(organizations.__all__))


def test_epic_37_does_not_couple_setc_organizations_to_ssr():
    assert all(not name.startswith("ssr") for name in organizations.__all__)
