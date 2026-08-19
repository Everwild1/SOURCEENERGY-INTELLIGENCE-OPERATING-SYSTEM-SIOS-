"""SC-E11 controlled testnet contract. Testnet passage grants no production authority."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable


class TestnetScenario(str, Enum):
    TRANSFER = "TRANSFER"
    SETTLEMENT = "SETTLEMENT"
    REWARD = "REWARD"
    TREASURY = "TREASURY"
    POLICY_DENIAL = "POLICY_DENIAL"
    REPLAY = "REPLAY"
    RACE = "RACE"
    OUTAGE_RECOVERY = "OUTAGE_RECOVERY"
    EMERGENCY_PAUSE_RELEASE = "EMERGENCY_PAUSE_RELEASE"
    KEY_ROTATION = "KEY_ROTATION"
    MIGRATION = "MIGRATION"
    RECONCILIATION = "RECONCILIATION"


REQUIRED_SCENARIOS = frozenset(TestnetScenario)


@dataclass(frozen=True)
class TestnetEnvironment:
    name: str
    supabase_project_ref: str
    synthetic_genesis_supply_minor: int
    production_keys_present: bool = False
    production_service_role_present: bool = False
    production_participant_data_present: bool = False
    production_wallets_present: bool = False

    def __post_init__(self) -> None:
        if not self.name.strip() or not self.supabase_project_ref.strip():
            raise ValueError("testnet name and Supabase project reference are required")
        if self.synthetic_genesis_supply_minor <= 0:
            raise ValueError("synthetic test genesis supply must be positive")
        if any((self.production_keys_present, self.production_service_role_present,
                self.production_participant_data_present, self.production_wallets_present)):
            raise ValueError("production material is prohibited in Source Coin testnet")


@dataclass(frozen=True)
class ScenarioEvidence:
    scenario: TestnetScenario
    passed: bool
    evidence_ref: str
    invariant_refs: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if not self.evidence_ref.strip():
            raise ValueError("evidence_ref is required")


@dataclass
class TestnetEvidenceManifest:
    environment: TestnetEnvironment
    results: list[ScenarioEvidence] = field(default_factory=list)
    reconciliation_passed: bool = False
    runbooks_exercised: bool = False
    unresolved_critical_findings: int = 0

    def record(self, evidence: ScenarioEvidence) -> None:
        self.results.append(evidence)

    def covered_scenarios(self) -> set[TestnetScenario]:
        return {item.scenario for item in self.results if item.passed}

    def missing_scenarios(self) -> set[TestnetScenario]:
        return set(REQUIRED_SCENARIOS) - self.covered_scenarios()

    def exit_ready(self) -> bool:
        return (
            not self.missing_scenarios()
            and self.reconciliation_passed
            and self.runbooks_exercised
            and self.unresolved_critical_findings == 0
        )

    def assert_exit_ready(self) -> None:
        if not self.exit_ready():
            raise ValueError("SC-E11 testnet exit criteria are not satisfied")


def deterministic_synthetic_allocation(total_minor: int, participant_ids: Iterable[str]) -> dict[str, int]:
    ids = sorted(set(participant_ids))
    if total_minor <= 0 or not ids:
        raise ValueError("positive supply and at least one synthetic participant are required")
    base, remainder = divmod(total_minor, len(ids))
    allocation = {participant_id: base for participant_id in ids}
    for participant_id in ids[:remainder]:
        allocation[participant_id] += 1
    if sum(allocation.values()) != total_minor:
        raise AssertionError("synthetic genesis allocation must conserve supply")
    return allocation
