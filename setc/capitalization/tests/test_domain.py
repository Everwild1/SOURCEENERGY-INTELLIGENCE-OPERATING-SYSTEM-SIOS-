from decimal import Decimal
import unittest

from setc.capitalization.domain import (
    ApprovalAction,
    ConnectivityStatus,
    InstitutionStatus,
    RelationshipState,
    SettlementInstruction,
    SettlementRail,
    SettlementStatus,
    VerificationStatus,
    assert_settlement_transition,
)


class InstitutionStatusTests(unittest.TestCase):
    def test_target_is_not_presented_as_live(self) -> None:
        status = InstitutionStatus(
            relationship_state=RelationshipState.TARGET,
            connectivity_status=ConnectivityStatus.NOT_CONNECTED,
            verification_status=VerificationStatus.UNVERIFIED,
        )
        self.assertIn("Registry target", status.public_label)

    def test_contracted_relationship_requires_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "require evidence"):
            InstitutionStatus(
                relationship_state=RelationshipState.CONTRACTED,
                connectivity_status=ConnectivityStatus.NOT_CONNECTED,
                verification_status=VerificationStatus.PENDING,
            )

    def test_live_requires_verified_production_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "PRODUCTION"):
            InstitutionStatus(
                relationship_state=RelationshipState.LIVE,
                connectivity_status=ConnectivityStatus.TEST,
                verification_status=VerificationStatus.VERIFIED,
                evidence_reference="agreement:123",
                last_verified_at="2026-08-20T12:00:00Z",
            )

        status = InstitutionStatus(
            relationship_state=RelationshipState.LIVE,
            connectivity_status=ConnectivityStatus.PRODUCTION,
            verification_status=VerificationStatus.VERIFIED,
            evidence_reference="agreement:123",
            last_verified_at="2026-08-20T12:00:00Z",
        )
        self.assertEqual(status.public_label, "Verified live connection")


class SettlementTests(unittest.TestCase):
    def test_positive_amount_and_currency_are_required(self) -> None:
        with self.assertRaisesRegex(ValueError, "positive"):
            SettlementInstruction(
                instruction_reference="STL-1",
                idempotency_key="idem-1",
                correlation_id="corr-1",
                rail=SettlementRail.FIAT_EXTERNAL,
                amount=Decimal("0"),
                currency="USD",
            )

    def test_settled_requires_external_finality_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "requires finality"):
            SettlementInstruction(
                instruction_reference="STL-2",
                idempotency_key="idem-2",
                correlation_id="corr-2",
                rail=SettlementRail.FIAT_EXTERNAL,
                amount=Decimal("10.00"),
                currency="USD",
                status=SettlementStatus.SETTLED,
            )

    def test_source_coin_finality_boundary(self) -> None:
        with self.assertRaisesRegex(ValueError, "SOURCE_COIN_DOMAIN"):
            SettlementInstruction(
                instruction_reference="STL-3",
                idempotency_key="idem-3",
                correlation_id="corr-3",
                rail=SettlementRail.SOURCE_COIN,
                amount=Decimal("10.00"),
                currency="SRC",
                status=SettlementStatus.SETTLED,
                finality_authority="CAPITALIZATION_BLOCK",
                confirmation_reference="sc:tx:1",
                settled_at="2026-08-20T12:00:00Z",
            )

    def test_transition_graph_blocks_skips(self) -> None:
        with self.assertRaisesRegex(ValueError, "invalid settlement transition"):
            assert_settlement_transition(
                SettlementStatus.DRAFT, SettlementStatus.SETTLED
            )
        assert_settlement_transition(
            SettlementStatus.DRAFT, SettlementStatus.PENDING_APPROVAL
        )


class ApprovalTests(unittest.TestCase):
    def test_self_approval_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "own request"):
            ApprovalAction(
                request_reference="APR-1",
                requested_by_actor="actor:1",
                actioned_by_actor="actor:1",
                decision="APPROVE",
                evidence_reference="evidence:1",
            )

    def test_material_decision_requires_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "require evidence"):
            ApprovalAction(
                request_reference="APR-2",
                requested_by_actor="actor:1",
                actioned_by_actor="actor:2",
                decision="REJECT",
            )


if __name__ == "__main__":
    unittest.main()
