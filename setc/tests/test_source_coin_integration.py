import unittest
from uuid import uuid4

from setc.core import new_setc_oid
from setc.source_coin.domain import (
    AccountStatus,
    CoinAccount,
    CoinTransaction,
    OrganizationWallet,
    TransactionType,
    WalletAuthorization,
    WalletRole,
)


class SourceCoinIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.organization_id = new_setc_oid()
        self.source = uuid4()
        self.destination = uuid4()

    def test_account_uses_canonical_setc_identifier(self):
        account = CoinAccount(uuid4(), self.organization_id)
        self.assertTrue(str(account.organization_id).startswith("SETC-OID-"))
        self.assertTrue(account.can_transact)

    def test_suspended_account_cannot_transact(self):
        account = CoinAccount(uuid4(), self.organization_id, AccountStatus.SUSPENDED)
        self.assertFalse(account.can_transact)

    def test_transfer_requires_distinct_source_and_destination(self):
        with self.assertRaises(ValueError):
            CoinTransaction(
                uuid4(), uuid4(), TransactionType.TRANSFER, 1,
                "idem-1", "corr-1", self.source, self.source,
            )

    def test_transfer_requires_both_accounts(self):
        with self.assertRaises(ValueError):
            CoinTransaction(
                uuid4(), uuid4(), TransactionType.TRANSFER, 1,
                "idem-2", "corr-2", self.source, None,
            )

    def test_mint_and_burn_require_correct_endpoint(self):
        with self.assertRaises(ValueError):
            CoinTransaction(uuid4(), uuid4(), TransactionType.MINT, 1, "idem-3", "corr-3")
        with self.assertRaises(ValueError):
            CoinTransaction(uuid4(), uuid4(), TransactionType.BURN, 1, "idem-4", "corr-4")

    def test_wallet_and_authorization_bind_to_organization(self):
        account_id = uuid4()
        wallet = OrganizationWallet(uuid4(), self.organization_id, account_id)
        authorization = WalletAuthorization(uuid4(), wallet.wallet_id, "principal:test", WalletRole.INITIATOR)
        self.assertEqual(wallet.organization_id, self.organization_id)
        self.assertTrue(authorization.active)

    def test_wallet_authorization_requires_principal(self):
        with self.assertRaises(ValueError):
            WalletAuthorization(uuid4(), uuid4(), "   ", WalletRole.SIGNER)


if __name__ == "__main__":
    unittest.main()
