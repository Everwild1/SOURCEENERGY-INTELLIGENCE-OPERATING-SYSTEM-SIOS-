from uuid import uuid4

import pytest

from setc.fashion.accelerator import FashionAcceleratorState, ParticipantBinding, TransitionRequest
from setc.fashion.accelerator_bindings import AuthorityReference, FashionAcceleratorBindingValidator
from setc.fashion.service import FashionContractError


class Authorities:
    def __init__(self):
        self.refs = {}

    def enrollment_exists(self, enrollment_id):
        return str(enrollment_id).endswith("1")

    def cohort_exists(self, cohort_id):
        return str(cohort_id).endswith("2")

    def evidence(self, reference):
        return self.refs.get(reference)


def test_market_gate_accepts_verified_market_access_authority():
    a = Authorities()
    a.refs["MAR-1"] = AuthorityReference("cruds", "market_access_requests", "MAR-1", True)
    validator = FashionAcceleratorBindingValidator(a)
    request = TransitionRequest(FashionAcceleratorState.CERTIFY, FashionAcceleratorState.MARKET, ("MAR-1",))
    assert validator.validate_transition_evidence(request)[0].domain == "cruds"


def test_capitalize_gate_rejects_market_evidence():
    a = Authorities()
    a.refs["MAR-1"] = AuthorityReference("cruds", "market_access_requests", "MAR-1", True)
    validator = FashionAcceleratorBindingValidator(a)
    request = TransitionRequest(FashionAcceleratorState.TRADE, FashionAcceleratorState.CAPITALIZE, ("MAR-1",))
    with pytest.raises(FashionContractError):
        validator.validate_transition_evidence(request)


def test_unverified_evidence_fails_closed():
    a = Authorities()
    a.refs["CAP-1"] = AuthorityReference("rw", "capital_readiness_profiles", "CAP-1", False)
    validator = FashionAcceleratorBindingValidator(a)
    request = TransitionRequest(FashionAcceleratorState.TRADE, FashionAcceleratorState.CAPITALIZE, ("CAP-1",))
    with pytest.raises(FashionContractError, match="not verified"):
        validator.validate_transition_evidence(request)


def test_measure_gate_accepts_wealth_ecology_authority():
    a = Authorities()
    a.refs["WY-1"] = AuthorityReference("rw", "wealth_yield_records", "WY-1", True)
    validator = FashionAcceleratorBindingValidator(a)
    request = TransitionRequest(FashionAcceleratorState.SCALE, FashionAcceleratorState.MEASURE, ("WY-1",))
    assert validator.validate_transition_evidence(request)


def test_equivalency_is_checked_against_each_skipped_state_authority():
    a = Authorities()
    a.refs["ASSESS-1"] = AuthorityReference("rw", "evidence", "ASSESS-1", True)
    a.refs["BAD-PROTECT"] = AuthorityReference("rw", "evidence", "BAD-PROTECT", True)
    validator = FashionAcceleratorBindingValidator(a)
    request = TransitionRequest(
        FashionAcceleratorState.REGISTER,
        FashionAcceleratorState.DESIGN,
        ("ASSESS-1",),
        equivalency_evidence={
            FashionAcceleratorState.ASSESS: ("ASSESS-1",),
            FashionAcceleratorState.PROTECT: ("BAD-PROTECT",),
        },
    )
    with pytest.raises(FashionContractError, match="protect"):
        validator.validate_equivalency(request)


def test_missing_enrollment_and_cohort_fail_closed():
    validator = FashionAcceleratorBindingValidator(Authorities())
    participant = ParticipantBinding(fashion_brand_id=uuid4())
    with pytest.raises(FashionContractError):
        validator.validate_enrollment(participant, enrollment_id=uuid4(), cohort_id=uuid4())
