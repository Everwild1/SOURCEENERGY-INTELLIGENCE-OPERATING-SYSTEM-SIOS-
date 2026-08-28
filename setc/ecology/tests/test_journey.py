import unittest

from setc.ecology.domain import AuthorityPosture, EcologyDomain, EcologyObjectReference
from setc.ecology.journey import (
    EcologyJourney,
    JourneyEdge,
    JourneyNode,
    JourneyStage,
    JourneyState,
    LifecycleDimension,
)


def ref(domain: EcologyDomain, kind: str, oid: str) -> EcologyObjectReference:
    return EcologyObjectReference(domain, kind, oid, domain.value, AuthorityPosture.REFERENCE_ONLY)


class EcologyJourneyTests(unittest.TestCase):
    def test_closed_loop_can_span_bounded_domains(self):
        research = JourneyNode(JourneyStage.RESEARCH_CREATION, ref(EcologyDomain.SOURCE_BLOCK, "research_asset", "r-1"))
        commercial = JourneyNode(JourneyStage.COMMERCIALIZATION, ref(EcologyDomain.HEI, "commercialization_case", "c-1"))
        market = JourneyNode(JourneyStage.MARKET_OPPORTUNITY, ref(EcologyDomain.WIM, "opportunity", "o-1"))
        impact = JourneyNode(JourneyStage.IMPACT, ref(EcologyDomain.WIM, "impact_record", "i-1"))
        reinvest = JourneyNode(JourneyStage.REINVESTMENT, ref(EcologyDomain.CAPITALIZATION, "allocation_projection", "a-1"))
        journey = EcologyJourney("eco-journey-1")
        journey.extend((research, commercial, market, impact, reinvest))
        journey.link(JourneyEdge(research, commercial, "commercializes"))
        journey.link(JourneyEdge(commercial, market, "seeks_market_access"))
        journey.link(JourneyEdge(market, impact, "produces_measured_impact"))
        journey.link(JourneyEdge(impact, reinvest, "informs_reinvestment"))
        journey.link(JourneyEdge(reinvest, research, "supports_next_cycle"))
        self.assertEqual(len(journey.edges), 5)

    def test_edge_never_transfers_authority_or_finality(self):
        a = JourneyNode(JourneyStage.TRANSACTION, ref(EcologyDomain.WIM, "transaction", "t-1"))
        b = JourneyNode(JourneyStage.SETTLEMENT_REFERENCE, ref(EcologyDomain.SOURCE_COIN, "transaction_reference", "sc-1"))
        edge = JourneyEdge(a, b, "references_settlement")
        self.assertFalse(edge.transfers_authority)
        self.assertFalse(edge.confers_financial_finality)

    def test_parallel_lifecycle_dimensions_are_preserved(self):
        source = ref(EcologyDomain.HEI, "commercialization_case", "c-2")
        node = JourneyNode(
            JourneyStage.COMMERCIALIZATION,
            source,
            (
                JourneyState(LifecycleDimension.COMMERCIALIZATION, "validated", source),
                JourneyState(LifecycleDimension.MARKET_READINESS, "pilot_ready", source),
                JourneyState(LifecycleDimension.CAPITAL_READINESS, "diligence", source),
            ),
        )
        self.assertEqual(len(node.states), 3)

    def test_state_cannot_claim_another_nodes_source(self):
        source = ref(EcologyDomain.HEI, "commercialization_case", "c-3")
        other = ref(EcologyDomain.WIM, "opportunity", "o-2")
        with self.assertRaises(ValueError):
            JourneyNode(
                JourneyStage.COMMERCIALIZATION,
                source,
                (JourneyState(LifecycleDimension.MARKET_READINESS, "ready", other),),
            )

    def test_edge_requires_registered_nodes(self):
        a = JourneyNode(JourneyStage.RESEARCH_CREATION, ref(EcologyDomain.SOURCE_BLOCK, "research", "r-2"))
        b = JourneyNode(JourneyStage.COMMERCIALIZATION, ref(EcologyDomain.CRUDS, "commercialization_project", "c-4"))
        journey = EcologyJourney("eco-journey-2", [a])
        with self.assertRaises(ValueError):
            journey.link(JourneyEdge(a, b, "commercializes"))


if __name__ == "__main__":
    unittest.main()
