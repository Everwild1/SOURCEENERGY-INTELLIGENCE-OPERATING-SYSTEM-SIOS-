import unittest


def may_execute_consequential(*, heartbeat_verified: bool, policy_decision: str, human_authorization: bool, adapter_enabled: bool) -> bool:
    """Reference invariant: biometric assurance never substitutes for authorization."""
    return bool(
        heartbeat_verified
        and policy_decision == "allow"
        and human_authorization
        and adapter_enabled
    )


class AuthorizationBoundaryTests(unittest.TestCase):
    def test_heartbeat_alone_cannot_execute(self):
        self.assertFalse(may_execute_consequential(heartbeat_verified=True, policy_decision="require_authorization", human_authorization=False, adapter_enabled=False))

    def test_even_institutional_step_up_requires_human_authorization(self):
        self.assertFalse(may_execute_consequential(heartbeat_verified=True, policy_decision="allow", human_authorization=False, adapter_enabled=True))

    def test_disabled_adapter_fails_closed(self):
        self.assertFalse(may_execute_consequential(heartbeat_verified=True, policy_decision="allow", human_authorization=True, adapter_enabled=False))

    def test_policy_denial_fails_closed(self):
        self.assertFalse(may_execute_consequential(heartbeat_verified=True, policy_decision="deny", human_authorization=True, adapter_enabled=True))

    def test_all_independent_gates_required(self):
        self.assertTrue(may_execute_consequential(heartbeat_verified=True, policy_decision="allow", human_authorization=True, adapter_enabled=True))


if __name__ == "__main__":
    unittest.main()
