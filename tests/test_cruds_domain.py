from uuid import uuid4

import pytest

from setc.cruds.domain import (
    CreatorArchetype,
    CreatorProfile,
    CreativeWork,
    SourceCoinSettlementReference,
    WimMarketAccessReference,
    WitnessVerificationReference,
)


def test_six_canonical_creator_archetypes_are_stable():
    assert {item.value for item in CreatorArchetype} == {
        "artist", "thinker", "adventurer", "maker", "producer", "dreamer"
    }


def test_creator_requires_authoritative_identity_reference():
    with pytest.raises(ValueError):
        CreatorProfile(id=uuid4(), display_name="Creator", identity_reference=" ")


def test_work_requires_title():
    with pytest.raises(ValueError):
        CreativeWork(id=uuid4(), creator_id=uuid4(), title=" ")


def test_witness_reference_never_confers_legal_ip_ownership():
    reference = WitnessVerificationReference("witness:example")
    assert reference.confers_legal_ip_ownership is False


def test_source_coin_reference_never_confers_settlement_finality():
    reference = SourceCoinSettlementReference("sourcecoin:example")
    assert reference.confers_settlement_finality is False


def test_wim_market_access_reference_is_correlation_only():
    assert WimMarketAccessReference("wim:request:example").value == "wim:request:example"
