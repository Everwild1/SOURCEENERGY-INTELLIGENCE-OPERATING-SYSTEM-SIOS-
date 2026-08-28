from datetime import datetime, timezone

import pytest

from setc.ecology.domain import EcologyCorrelation, EcologyDomain, EcologyObjectReference
from setc.ecology.events import EcologyEventEnvelope, EcologyEventName, require_material_command_idempotency


def ref(domain=EcologyDomain.WIM, authority="wim"):
    return EcologyObjectReference(domain, "commercialization_project", "cp-1", authority)


def envelope(**overrides):
    now = datetime.now(timezone.utc)
    values = dict(
        event_id="evt-1",
        event_name=EcologyEventName.COMMERCIALIZATION_ADVANCED,
        contract_version="1.0",
        producer=EcologyDomain.WIM,
        source_authority="wim",
        correlation=EcologyCorrelation("corr-1", idempotency_key="idem-1"),
        subject=ref(),
        occurred_at=now,
        recorded_at=now,
    )
    values.update(overrides)
    return EcologyEventEnvelope(**values)


def test_event_never_transfers_authority_or_finality():
    event = envelope()
    assert event.confers_source_authority is False
    assert event.confers_settlement_finality is False


def test_producer_must_match_subject_domain():
    with pytest.raises(ValueError):
        envelope(producer=EcologyDomain.HEI)


def test_source_authority_must_match_subject():
    with pytest.raises(ValueError):
        envelope(source_authority="ecology")


def test_material_events_require_idempotency():
    event = envelope(correlation=EcologyCorrelation("corr-1"))
    with pytest.raises(ValueError):
        require_material_command_idempotency(event)


def test_material_event_with_idempotency_is_accepted():
    require_material_command_idempotency(envelope())


def test_naive_timestamps_are_rejected():
    naive = datetime.now()
    with pytest.raises(ValueError):
        envelope(occurred_at=naive, recorded_at=naive)


def test_source_coin_settlement_reference_is_not_finality():
    subject = EcologyObjectReference(EcologyDomain.SOURCE_COIN, "settlement_instruction", "s-1", "source_coin")
    event = envelope(
        event_name=EcologyEventName.SETTLEMENT_REFERENCED,
        producer=EcologyDomain.SOURCE_COIN,
        source_authority="source_coin",
        subject=subject,
    )
    assert event.confers_settlement_finality is False
