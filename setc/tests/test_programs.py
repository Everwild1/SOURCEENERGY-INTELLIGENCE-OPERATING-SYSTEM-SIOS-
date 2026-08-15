from datetime import datetime, timezone
import unittest

from setc.core import SETCIdentifier
from setc.organizations.programs import (
    Cohort,
    Program,
    ProgramParticipation,
    ProgramType,
)


def oid(hex_value: str) -> SETCIdentifier:
    return SETCIdentifier(f"SETC-OID-{hex_value}")


class ProgramCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.operator = oid("00000000000000000000000000000001")
        self.sponsor = oid("00000000000000000000000000000002")
        self.participant = oid("00000000000000000000000000000003")
        self.program_id = oid("00000000000000000000000000000004")
        self.cohort_id = oid("00000000000000000000000000000005")
        self.participation_id = oid("00000000000000000000000000000006")

    def test_program_requires_name(self) -> None:
        with self.assertRaises(ValueError):
            Program(self.program_id, self.operator, "  ", ProgramType.INCUBATION)

    def test_operator_is_not_duplicated_as_sponsor(self) -> None:
        with self.assertRaises(ValueError):
            Program(
                self.program_id,
                self.operator,
                "Venture Incubator",
                ProgramType.INCUBATION,
                sponsor_organization_ids=(self.operator,),
            )

    def test_sponsors_are_unique(self) -> None:
        with self.assertRaises(ValueError):
            Program(
                self.program_id,
                self.operator,
                "Research Commercialization",
                ProgramType.RESEARCH,
                sponsor_organization_ids=(self.sponsor, self.sponsor),
            )

    def test_cohort_window_is_ordered(self) -> None:
        later = datetime(2026, 9, 1, tzinfo=timezone.utc)
        earlier = datetime(2026, 8, 1, tzinfo=timezone.utc)
        with self.assertRaises(ValueError):
            Cohort(self.cohort_id, self.program_id, "Fall 2026", starts_at=later, ends_at=earlier)

    def test_participation_window_is_ordered(self) -> None:
        later = datetime(2026, 9, 1, tzinfo=timezone.utc)
        earlier = datetime(2026, 8, 1, tzinfo=timezone.utc)
        with self.assertRaises(ValueError):
            ProgramParticipation(
                self.participation_id,
                self.program_id,
                self.participant,
                cohort_id=self.cohort_id,
                admitted_at=later,
                completed_at=earlier,
            )

    def test_participation_preserves_canonical_organization_identity(self) -> None:
        participation = ProgramParticipation(
            self.participation_id,
            self.program_id,
            self.participant,
            cohort_id=self.cohort_id,
        )
        self.assertEqual(participation.participant_organization_id, self.participant)


if __name__ == "__main__":
    unittest.main()
