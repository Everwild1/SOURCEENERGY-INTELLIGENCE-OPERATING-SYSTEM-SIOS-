from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.incubation import (
    HandoffType,
    IncubationApplication,
    IncubationMilestone,
    IncubationParticipation,
    IncubationState,
    MentorAssignment,
    ProgramHandoff,
    ResourceAccessGrant,
)


def sid(prefix: str, value: int) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-{prefix}-{value:032x}")


class IncubationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.program = sid("OID", 1)
        self.participant = sid("OID", 2)
        self.mentor = sid("OID", 3)
        self.participation = sid("OID", 4)

    def test_blank_application_evidence_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            IncubationApplication(sid("OID", 5), self.program, self.participant, evidence_reference=" ")

    def test_completion_cannot_precede_admission(self) -> None:
        admitted = datetime(2026, 8, 15, tzinfo=timezone.utc)
        completed = datetime(2026, 8, 14, tzinfo=timezone.utc)
        with self.assertRaises(ValueError):
            IncubationParticipation(
                self.participation,
                self.program,
                self.participant,
                admitted_at=admitted,
                completed_at=completed,
            )

    def test_research_and_ip_links_are_references(self) -> None:
        record = IncubationParticipation(
            self.participation,
            self.program,
            self.participant,
            research_reference="research:123",
            ip_reference="ip:456",
        )
        self.assertEqual(record.research_reference, "research:123")
        self.assertEqual(record.ip_reference, "ip:456")

    def test_mentor_scope_is_required(self) -> None:
        with self.assertRaises(ValueError):
            MentorAssignment(sid("OID", 6), self.participation, self.mentor, " ")

    def test_resource_access_window_is_ordered(self) -> None:
        start = datetime(2026, 9, 2, tzinfo=timezone.utc)
        end = datetime(2026, 9, 1, tzinfo=timezone.utc)
        with self.assertRaises(ValueError):
            ResourceAccessGrant(sid("OID", 7), self.participation, "LAB", self.mentor, start, end)

    def test_milestone_can_carry_unresolved_risk(self) -> None:
        milestone = IncubationMilestone(
            sid("OID", 8), self.participation, "Customer validation", unresolved_risk="Regulatory review pending"
        )
        self.assertEqual(milestone.unresolved_risk, "Regulatory review pending")

    def test_graduation_is_distinct_from_capital_readiness_handoff(self) -> None:
        participation = IncubationParticipation(
            self.participation, self.program, self.participant, state=IncubationState.GRADUATED
        )
        handoff = ProgramHandoff(sid("OID", 9), self.participation, HandoffType.CAPITAL_READINESS)
        self.assertEqual(participation.state, IncubationState.GRADUATED)
        self.assertEqual(handoff.handoff_type, HandoffType.CAPITAL_READINESS)
        self.assertFalse(hasattr(participation, "capital_ready"))


if __name__ == "__main__":
    unittest.main()
