import unittest
from uuid import uuid4

from setc.source_coin.config import SourceCoinFeatureGates
from setc.source_coin.domain import CoinTransaction, TransactionType


class SourceCoinSprint1Tests(unittest.TestCase):
    def test_production_gates_default_closed(self):
        gates = SourceCoinFeatureGates()
        self.assertFalse(gates.mint_enabled)
        self.assertFalse(gates.burn_enabled)
        self.assertFalse(gates.production_economy_enabled)
        gates.assert_production_closed()

    def test_any_economic_activation_requires_sc_e12(self):
        with self.assertRaises(RuntimeError):
            SourceCoinFeatureGates(mint_enabled=True).assert_production_closed()

    def test_transaction_requires_positive_minor_units(self):
        with self.assertRaises(ValueError):
            CoinTransaction(
                transaction_id=uuid4(),
                asset_id=uuid4(),
                transaction_type=TransactionType.TRANSFER,
                amount_minor=0,
                idempotency_key="req-1",
                correlation_id="corr-1",
                source_account_id=uuid4(),
                destination_account_id=uuid4(),
            )

    def test_transaction_requires_idempotency_key(self):
        with self.assertRaises(ValueError):
            CoinTransaction(
                transaction_id=uuid4(),
                asset_id=uuid4(),
                transaction_type=TransactionType.TRANSFER,
                amount_minor=1,
                idempotency_key=" ",
                correlation_id="corr-1",
                source_account_id=uuid4(),
                destination_account_id=uuid4(),
            )


if __name__ == "__main__":
    unittest.main()
