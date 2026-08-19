import unittest
from uuid import uuid4

from setc.source_coin.domain import CoinTransaction, TransactionStatus, TransactionType
from setc.source_coin.security import (
    EconomicSnapshot,
    EmergencyState,
    assert_emergency_state_allows_execution,
    assert_no_duplicate_settlement,
    assert_participant_operation_allowed,
    assert_supply_conservation,
    assert_transfer_conservation,
)


class SourceCoinSecurityInvariantTests(unittest.TestCase):
    def test_supply_conservation_accepts_authorized_state(self):
        snapshot = EconomicSnapshot(1000, 200, 50, 1150)
        assert_supply_conservation(snapshot)

    def test_supply_conservation_rejects_divergence(self):
        with self.assertRaisesRegex(ValueError, "supply invariant violated"):
            assert_supply_conservation(EconomicSnapshot(1000, 200, 50, 1149))

    def test_transfer_conservation_rejects_mismatch(self):
        with self.assertRaisesRegex(ValueError, "transfer conservation"):
            assert_transfer_conservation(100, 99)

    def test_duplicate_settlement_is_rejected(self):
        source = uuid4()
        destination = uuid4()
        txs = [
            CoinTransaction(uuid4(), uuid4(), TransactionType.TRANSFER, 10, "same-key", "c1", source, destination, status=TransactionStatus.SETTLED),
            CoinTransaction(uuid4(), uuid4(), TransactionType.TRANSFER, 10, "same-key", "c2", source, destination, status=TransactionStatus.SETTLED),
        ]
        with self.assertRaisesRegex(ValueError, "duplicate settled"):
            assert_no_duplicate_settlement(txs)

    def test_participant_cannot_mint_or_burn(self):
        for operation in (TransactionType.MINT, TransactionType.BURN):
            with self.assertRaises(PermissionError):
                assert_participant_operation_allowed(operation)

    def test_pause_blocks_economic_execution(self):
        with self.assertRaisesRegex(PermissionError, "paused"):
            assert_emergency_state_allows_execution(EmergencyState.PAUSED)

    def test_active_state_allows_execution(self):
        assert_emergency_state_allows_execution(EmergencyState.ACTIVE)


if __name__ == "__main__":
    unittest.main()
