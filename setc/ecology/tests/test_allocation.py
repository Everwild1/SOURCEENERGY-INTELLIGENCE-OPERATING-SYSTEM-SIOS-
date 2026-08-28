import unittest
from decimal import Decimal

from setc.ecology.allocation import (
    AllocationCandidate,
    AllocationPolicy,
    AllocationTarget,
    ProposalStatus,
    RegenerativeAllocationProposal,
    build_regenerative_proposal,
)


class RegenerativeAllocationTests(unittest.TestCase):
    def candidate(self, ref, target, score="0.8", confidence="0.8", authority="wim"):
        return AllocationCandidate(ref, target, ("intel-1",), Decimal(score), Decimal(confidence), authority)

    def test_proposal_never_becomes_execution_authority(self):
        proposal = build_regenerative_proposal(
            proposal_id="p1", journey_id="j1", currency_or_unit="USD", available_amount=Decimal("100"),
            candidates=(self.candidate("a", AllocationTarget.RESEARCH, authority="wim"), self.candidate("b", AllocationTarget.COMMUNITY, authority="hei")),
            policy=AllocationPolicy(maximum_candidate_share=Decimal("0.5"), maximum_authority_share=Decimal("0.6")),
        )
        self.assertFalse(proposal.is_payment_instruction)
        self.assertFalse(proposal.confers_settlement_finality)
        self.assertFalse(proposal.confers_ledger_or_treasury_authority)
        self.assertFalse(proposal.confers_fiduciary_or_compliance_approval)

    def test_external_authorization_requires_external_reference(self):
        with self.assertRaises(ValueError):
            RegenerativeAllocationProposal("p", "j", "USD", Decimal("0"), (), status=ProposalStatus.EXTERNALLY_AUTHORIZED)

    def test_low_confidence_candidate_is_ineligible(self):
        proposal = build_regenerative_proposal(
            proposal_id="p", journey_id="j", currency_or_unit="USD", available_amount=Decimal("100"),
            candidates=(self.candidate("low", AllocationTarget.RESEARCH, confidence="0.2"),),
            policy=AllocationPolicy(minimum_confidence=Decimal("0.5")),
        )
        self.assertEqual((), tuple(proposal.lines))

    def test_candidate_cap_is_enforced(self):
        proposal = build_regenerative_proposal(
            proposal_id="p", journey_id="j", currency_or_unit="USD", available_amount=Decimal("100"),
            candidates=(self.candidate("a", AllocationTarget.RESEARCH, authority="a1"), self.candidate("b", AllocationTarget.COMMUNITY, score="0.1", authority="a2")),
            policy=AllocationPolicy(maximum_candidate_share=Decimal("0.4"), maximum_authority_share=Decimal("0.8")),
        )
        self.assertTrue(all(line.proposed_amount <= Decimal("40") for line in proposal.lines))

    def test_authority_concentration_fails_closed(self):
        with self.assertRaises(ValueError):
            build_regenerative_proposal(
                proposal_id="p", journey_id="j", currency_or_unit="USD", available_amount=Decimal("100"),
                candidates=(self.candidate("a", AllocationTarget.RESEARCH, authority="same"), self.candidate("b", AllocationTarget.COMMUNITY, authority="same")),
                policy=AllocationPolicy(maximum_candidate_share=Decimal("0.5"), maximum_authority_share=Decimal("0.4")),
            )

    def test_proposal_cannot_overallocate(self):
        from setc.ecology.allocation import AllocationLine
        with self.assertRaises(ValueError):
            RegenerativeAllocationProposal("p", "j", "USD", Decimal("10"), (AllocationLine("x", AllocationTarget.RESEARCH, "wim", Decimal("11"), Decimal("1"), ("i",)),))


if __name__ == "__main__":
    unittest.main()
