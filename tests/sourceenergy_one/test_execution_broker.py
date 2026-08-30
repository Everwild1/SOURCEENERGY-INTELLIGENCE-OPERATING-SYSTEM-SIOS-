import unittest


def may_execute(*, authorization_status: str, adapter_enabled: bool, adapter_mode: str, already_executed: bool) -> bool:
    return (
        authorization_status == "approved"
        and adapter_enabled
        and adapter_mode == "execute"
        and not already_executed
    )


class ExecutionBrokerTests(unittest.TestCase):
    def test_pending_authorization_cannot_execute(self):
        self.assertFalse(may_execute(authorization_status="pending", adapter_enabled=True, adapter_mode="execute", already_executed=False))

    def test_declined_authorization_cannot_execute(self):
        self.assertFalse(may_execute(authorization_status="declined", adapter_enabled=True, adapter_mode="execute", already_executed=False))

    def test_disabled_adapter_cannot_execute(self):
        self.assertFalse(may_execute(authorization_status="approved", adapter_enabled=False, adapter_mode="execute", already_executed=False))

    def test_non_execute_adapter_cannot_execute(self):
        self.assertFalse(may_execute(authorization_status="approved", adapter_enabled=True, adapter_mode="propose", already_executed=False))

    def test_replay_cannot_execute(self):
        self.assertFalse(may_execute(authorization_status="approved", adapter_enabled=True, adapter_mode="execute", already_executed=True))

    def test_all_final_gates_required(self):
        self.assertTrue(may_execute(authorization_status="approved", adapter_enabled=True, adapter_mode="execute", already_executed=False))


if __name__ == "__main__":
    unittest.main()
