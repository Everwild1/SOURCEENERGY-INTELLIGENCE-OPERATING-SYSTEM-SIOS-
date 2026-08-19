import unittest

from setc.source_coin.production_readiness import (
    AuditFinding,
    ConfigurationFreeze,
    EvidenceItem,
    FindingDisposition,
    FindingSeverity,
    GovernanceAuthorization,
    ProductionReadinessGate,
    REQUIRED_EVIDENCE,
    activation_environment_defaults,
)


def full_evidence():
    return tuple(EvidenceItem(control, f"evidence:{control}", True) for control in REQUIRED_EVIDENCE)


def freeze():
    return ConfigurationFreeze("release-sha", "migration-009", "policy-v1", "source-coin-prod")


class ProductionReadinessTests(unittest.TestCase):
    def test_defaults_remain_closed(self):
        self.assertEqual(
            activation_environment_defaults(),
            {
                "SOURCE_COIN_MINT_ENABLED": "false",
                "SOURCE_COIN_BURN_ENABLED": "false",
                "SOURCE_COIN_PRODUCTION_ECONOMY_ENABLED": "false",
            },
        )

    def test_missing_evidence_blocks_readiness(self):
        gate = ProductionReadinessGate((), (), freeze(), True, True, True, True)
        self.assertFalse(gate.audit_ready)
        self.assertIn("SC-E01", gate.readiness_failures())

    def test_open_high_finding_blocks_release(self):
        finding = AuditFinding("A-1", FindingSeverity.HIGH, FindingDisposition.OPEN, "audit:A-1")
        gate = ProductionReadinessGate(full_evidence(), (finding,), freeze(), True, True, True, True)
        self.assertFalse(gate.audit_ready)
        self.assertIn("MATERIAL_AUDIT_FINDINGS", gate.readiness_failures())

    def test_audit_ready_does_not_equal_activation_authorized(self):
        gate = ProductionReadinessGate(full_evidence(), (), freeze(), True, True, True, True)
        self.assertTrue(gate.audit_ready)
        self.assertFalse(gate.activation_authorized)
        with self.assertRaises(PermissionError):
            gate.assert_activation_authorized("TRANSFER")

    def test_explicit_authorization_is_scope_limited(self):
        auth = GovernanceAuthorization("AUTH-1", "governance-board", ("TRANSFER",), "approval:AUTH-1", True)
        gate = ProductionReadinessGate(full_evidence(), (), freeze(), True, True, True, True, auth)
        self.assertTrue(gate.activation_authorized)
        gate.assert_activation_authorized("TRANSFER")
        with self.assertRaises(PermissionError):
            gate.assert_activation_authorized("MINT")


if __name__ == "__main__":
    unittest.main()
