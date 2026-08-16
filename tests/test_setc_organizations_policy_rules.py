from datetime import UTC, datetime

import pytest

from setc.core import SETCIdentifier
from setc.organizations import (
    InstitutionalPolicy,
    PolicyApproval,
    PolicyState,
    RuleEvaluation,
)


def sid(value: str) -> SETCIdentifier:
    return SETCIdentifier(value)


def test_active_policy_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        InstitutionalPolicy(
            policy_id=sid("policy-1"), organization_id=sid("org-1"), name="Treasury",
            version="1.0", policy_reference="POL-001", state=PolicyState.ACTIVE,
        )


def test_policy_cannot_supersede_itself() -> None:
    with pytest.raises(ValueError, match="supersede itself"):
        InstitutionalPolicy(
            policy_id=sid("policy-1"), organization_id=sid("org-1"), name="Treasury",
            version="1.0", policy_reference="POL-001", supersedes_policy_id=sid("policy-1"),
        )


def test_policy_requester_cannot_self_approve() -> None:
    with pytest.raises(ValueError, match="self-approve"):
        PolicyApproval(
            approval_id=sid("approval-1"), policy_id=sid("policy-1"),
            requesting_organization_id=sid("org-1"), approving_organization_id=sid("org-1"),
            authority_reference="AUTH-1", evidence_reference="EV-1",
            approved_at=datetime.now(UTC),
        )


def test_material_rule_evaluation_requires_evidence() -> None:
    with pytest.raises(ValueError, match="requires evidence"):
        RuleEvaluation(
            evaluation_id=sid("evaluation-1"), rule_id=sid("rule-1"),
            subject_reference="decision-1", evaluating_organization_id=sid("org-2"),
            applicable=True, satisfied=False, evaluated_at=datetime.now(UTC),
        )
