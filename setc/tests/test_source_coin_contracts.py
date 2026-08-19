import unittest
from uuid import uuid4

from setc.source_coin.contracts import (
    API_VERSION,
    SCHEMA_VERSION,
    APIError,
    DomainEvent,
    DomainEventType,
    ErrorCode,
    RequestEnvelope,
)


class SourceCoinContractTests(unittest.TestCase):
    def test_request_envelope_requires_idempotency_and_correlation(self):
        with self.assertRaises(ValueError):
            RequestEnvelope(uuid4(), "corr", "", "actor")
        with self.assertRaises(ValueError):
            RequestEnvelope(uuid4(), "", "idem", "actor")

    def test_request_envelope_rejects_unknown_api_version(self):
        with self.assertRaisesRegex(ValueError, "unsupported API version"):
            RequestEnvelope(uuid4(), "corr", "idem", "actor", api_version="v2")
        self.assertEqual(API_VERSION, "v1")

    def test_domain_event_has_stable_version_and_identity(self):
        event = DomainEvent(
            DomainEventType.TRANSACTION_SETTLED,
            "CoinTransaction",
            str(uuid4()),
            "corr-1",
            {"amountMinor": 10},
            causation_id="request-1",
        )
        self.assertEqual(event.schema_version, SCHEMA_VERSION)
        self.assertEqual(event.event_type.value, "TransactionSettled")
        self.assertTrue(event.event_id)

    def test_domain_event_rejects_unknown_schema_version(self):
        with self.assertRaisesRegex(ValueError, "unsupported schema version"):
            DomainEvent(
                DomainEventType.REWARD_EXECUTED,
                "RewardGrant",
                str(uuid4()),
                "corr-2",
                {},
                schema_version="2.0",
            )

    def test_api_error_uses_machine_readable_code(self):
        error = APIError(ErrorCode.POLICY_DENIED, "operation denied", "corr-3")
        self.assertEqual(error.code.value, "POLICY_DENIED")


if __name__ == "__main__":
    unittest.main()
