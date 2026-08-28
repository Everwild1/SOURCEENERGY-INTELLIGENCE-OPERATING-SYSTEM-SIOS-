from uuid import uuid4

import pytest

from setc.fashion.accelerator import (
    FashionAccelerator,
    FashionAcceleratorState as State,
    ParticipantBinding,
    TransitionOutcome,
    TransitionRequest,
)
from setc.fashion.service import FashionContractError, FashionRequestContext


def context():
    return FashionRequestContext(subject="reviewer:test", roles=frozenset())


def participant():
    return ParticipantBinding(organization_oid="SEG-TEST")


def test_sequential_evidence_gate_advances_when_approved():
    decision = FashionAccelerator.evaluate(
        context(), participant(),
        TransitionRequest(State.DISCOVER, State.REGISTER, ("evidence:identity",)),
        outcome=TransitionOutcome.APPROVED,
    )
    assert decision.resulting_state is State.REGISTER
    assert decision.request_id


def test_transition_without_evidence_fails_closed():
    with pytest.raises(FashionContractError):
        FashionAccelerator.evaluate(
            context(), participant(),
            TransitionRequest(State.REGISTER, State.ASSESS, ()),
            outcome=TransitionOutcome.APPROVED,
        )


def test_skipped_state_requires_equivalency_for_every_bypassed_gate():
    with pytest.raises(FashionContractError):
        FashionAccelerator.evaluate(
            context(), participant(),
            TransitionRequest(State.ASSESS, State.DESIGN, ("evidence:design",)),
            outcome=TransitionOutcome.APPROVED,
        )

    decision = FashionAccelerator.evaluate(
        context(), participant(),
        TransitionRequest(
            State.ASSESS,
            State.DESIGN,
            ("evidence:design",),
            equivalency_evidence={State.PROTECT: ("evidence:rights-review",)},
        ),
        outcome=TransitionOutcome.APPROVED,
    )
    assert decision.resulting_state is State.DESIGN


def test_remediation_does_not_advance_state():
    decision = FashionAccelerator.evaluate(
        context(), participant(),
        TransitionRequest(State.VALIDATE, State.PRODUCE, ("evidence:readiness",)),
        outcome=TransitionOutcome.REMEDIATION_REQUIRED,
        rationale="supplier evidence incomplete",
    )
    assert decision.resulting_state is State.VALIDATE


def test_rejection_requires_rationale_and_does_not_advance():
    with pytest.raises(FashionContractError):
        FashionAccelerator.evaluate(
            context(), participant(),
            TransitionRequest(State.MARKET, State.TRADE, ("evidence:buyer",)),
            outcome=TransitionOutcome.REJECTED,
        )


def test_participant_binding_must_reference_authoritative_identity():
    with pytest.raises(FashionContractError):
        FashionAccelerator.evaluate(
            context(), ParticipantBinding(),
            TransitionRequest(State.DISCOVER, State.REGISTER, ("evidence:identity",)),
            outcome=TransitionOutcome.APPROVED,
        )


def test_backward_or_same_state_transition_is_rejected():
    with pytest.raises(FashionContractError):
        FashionAccelerator.evaluate(
            context(), participant(),
            TransitionRequest(State.TRADE, State.MARKET, ("evidence:x",)),
            outcome=TransitionOutcome.APPROVED,
        )
