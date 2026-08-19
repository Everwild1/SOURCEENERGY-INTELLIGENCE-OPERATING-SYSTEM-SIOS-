from uuid import uuid4

import pytest

from setc.source_coin.config import SourceCoinFeatureGates
from setc.source_coin.domain import CoinTransaction, TransactionType


def test_production_gates_default_closed():
    gates = SourceCoinFeatureGates()
    assert gates.mint_enabled is False
    assert gates.burn_enabled is False
    assert gates.production_economy_enabled is False
    gates.assert_production_closed()


def test_any_economic_activation_requires_sc_e12():
    with pytest.raises(RuntimeError):
        SourceCoinFeatureGates(mint_enabled=True).assert_production_closed()


def test_transaction_requires_positive_minor_units():
    with pytest.raises(ValueError):
        CoinTransaction(
            transaction_id=uuid4(),
            asset_id=uuid4(),
            transaction_type=TransactionType.TRANSFER,
            amount_minor=0,
            idempotency_key="req-1",
            correlation_id="corr-1",
        )


def test_transaction_requires_idempotency_key():
    with pytest.raises(ValueError):
        CoinTransaction(
            transaction_id=uuid4(),
            asset_id=uuid4(),
            transaction_type=TransactionType.TRANSFER,
            amount_minor=1,
            idempotency_key=" ",
            correlation_id="corr-1",
        )
