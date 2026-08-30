import unittest


class MockAdapter:
    key = "mock-staging-execute"
    mode = "execute"
    enabled = True
    external_side_effects = False
    production_prohibited = True


def execute_fixture(*, authorization_status: str, adapter: MockAdapter, already_executed: bool):
    if authorization_status != "approved":
        raise PermissionError("authorization request not approved")
    if not adapter.enabled or adapter.mode != "execute":
        raise PermissionError("adapter not executable")
    if not adapter.production_prohibited or adapter.external_side_effects:
        raise PermissionError("fixture adapter safety boundary violated")
    if already_executed:
        raise RuntimeError("authorized action already executed for adapter")
    return {
        "status": "executed",
        "adapter_key": adapter.key,
        "external_side_effects": False,
        "fixture": True,
    }


class MockExecutionPathTests(unittest.TestCase):
    def test_positive_path_requires_approved_authorization(self):
        receipt = execute_fixture(authorization_status="approved", adapter=MockAdapter(), already_executed=False)
        self.assertEqual(receipt["status"], "executed")
        self.assertFalse(receipt["external_side_effects"])

    def test_pending_is_blocked(self):
        with self.assertRaises(PermissionError):
            execute_fixture(authorization_status="pending", adapter=MockAdapter(), already_executed=False)

    def test_replay_is_blocked(self):
        with self.assertRaises(RuntimeError):
            execute_fixture(authorization_status="approved", adapter=MockAdapter(), already_executed=True)

    def test_fixture_cannot_have_external_side_effects(self):
        adapter = MockAdapter()
        adapter.external_side_effects = True
        with self.assertRaises(PermissionError):
            execute_fixture(authorization_status="approved", adapter=adapter, already_executed=False)


if __name__ == "__main__":
    unittest.main()
