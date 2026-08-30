import unittest


def execute_gate(*, authorization_status, expired, consumed, intent_matches, adapter_enabled, adapter_mode, replayed):
    if authorization_status != "approved":
        raise PermissionError("authorization request not approved")
    if expired:
        raise PermissionError("authorization request expired")
    if consumed:
        raise PermissionError("authorization request already consumed")
    if not intent_matches:
        raise PermissionError("execution intent does not match authorization request")
    if not adapter_enabled:
        raise PermissionError("adapter disabled")
    if adapter_mode != "execute":
        raise PermissionError("adapter not executable")
    if replayed:
        raise RuntimeError("authorized action already executed for adapter")
    return {"status": "executed", "authorization_consumed": True}


class ExecutionBrokerHardeningTests(unittest.TestCase):
    def valid(self, **overrides):
        args = dict(
            authorization_status="approved",
            expired=False,
            consumed=False,
            intent_matches=True,
            adapter_enabled=True,
            adapter_mode="execute",
            replayed=False,
        )
        args.update(overrides)
        return args

    def test_valid_execution_consumes_authorization(self):
        receipt = execute_gate(**self.valid())
        self.assertEqual(receipt["status"], "executed")
        self.assertTrue(receipt["authorization_consumed"])

    def test_expired_authorization_fails_closed(self):
        with self.assertRaises(PermissionError):
            execute_gate(**self.valid(expired=True))

    def test_consumed_authorization_fails_closed(self):
        with self.assertRaises(PermissionError):
            execute_gate(**self.valid(consumed=True))

    def test_execution_intent_must_match_authorization(self):
        with self.assertRaises(PermissionError):
            execute_gate(**self.valid(intent_matches=False))

    def test_disabled_or_non_execute_adapter_fails_closed(self):
        with self.assertRaises(PermissionError):
            execute_gate(**self.valid(adapter_enabled=False))
        with self.assertRaises(PermissionError):
            execute_gate(**self.valid(adapter_mode="propose"))

    def test_replay_fails_closed(self):
        with self.assertRaises(RuntimeError):
            execute_gate(**self.valid(replayed=True))


if __name__ == "__main__":
    unittest.main()
