import unittest

from setc.capitalization.integration_contracts import CapitalizationEnvelope


class CapitalizationEnvelopeTests(unittest.TestCase):
    def test_builds_versioned_envelope(self) -> None:
        envelope = CapitalizationEnvelope.build(
            contract_name="capitalization.settlement.requested",
            contract_version="1.0",
            correlation_id="corr-1",
            producer="WIM",
            payload={"transactionId": "tx-1"},
        )
        result = envelope.to_dict()
        self.assertEqual(result["contract_version"], "1.0")
        self.assertEqual(result["producer"], "WIM")
        self.assertEqual(result["payload"]["transactionId"], "tx-1")
        self.assertTrue(result["event_id"])

    def test_rejects_unsupported_version(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported"):
            CapitalizationEnvelope.build(
                contract_name="capitalization.test",
                contract_version="2.0",
                correlation_id="corr-2",
                producer="SETC",
                payload={},
            )

    def test_requires_identity_fields(self) -> None:
        with self.assertRaisesRegex(ValueError, "required"):
            CapitalizationEnvelope.build(
                contract_name="capitalization.test",
                contract_version="1.0",
                correlation_id=" ",
                producer="SETC",
                payload={},
            )


if __name__ == "__main__":
    unittest.main()
