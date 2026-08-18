"""Regression gates for SETC Phase II-C ecosystem integration contracts."""

import pytest

from setc.integration_contracts import (
    ContractDirection,
    IntegrationContract,
    IntegrationEnvelope,
    validate_envelope,
)


def contract() -> IntegrationContract:
    return IntegrationContract(
        name="organizations.snapshot",
        version="1.0",
        approved_consumers=frozenset({"sourceenergy-research", "sourceenergy-governance"}),
    )


def test_contract_requires_supported_version_and_approved_consumers():
    with pytest.raises(ValueError):
        IntegrationContract(name="organizations.snapshot", version="9.9", approved_consumers=frozenset({"consumer"}))
    with pytest.raises(ValueError):
        IntegrationContract(name="organizations.snapshot", version="1.0")


def test_contract_normalizes_identity_fields():
    value = IntegrationContract(
        name="  organizations.snapshot  ",
        version=" 1.0 ",
        approved_consumers=frozenset({"  sourceenergy-research  "}),
    )
    assert value.name == "organizations.snapshot"
    assert value.version == "1.0"
    assert value.approved_consumers == frozenset({"sourceenergy-research"})


def test_envelope_fails_closed_for_unapproved_consumer():
    with pytest.raises(ValueError):
        IntegrationEnvelope.build(
            contract(),
            consumer="unknown-consumer",
            direction=ContractDirection.REQUEST,
            payload={"organization_oid": "example"},
        )


def test_envelope_is_machine_readable_and_validates_against_contract():
    value = IntegrationEnvelope.build(
        contract(),
        consumer="sourceenergy-research",
        direction=ContractDirection.RESPONSE,
        payload={"status": "available", "count": 2},
    )
    validate_envelope(contract(), value)
    assert value.to_dict() == {
        "contract_name": "organizations.snapshot",
        "contract_version": "1.0",
        "consumer": "sourceenergy-research",
        "direction": "RESPONSE",
        "payload": {"status": "available", "count": 2},
    }


def test_validation_rejects_contract_version_drift():
    value = IntegrationEnvelope(
        contract_name="organizations.snapshot",
        contract_version="2.0",
        consumer="sourceenergy-research",
        direction=ContractDirection.REQUEST,
        payload={},
    )
    with pytest.raises(ValueError):
        validate_envelope(contract(), value)
