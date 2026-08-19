"""Source Coin production safety gates.

Governance authority: SC-01 / SC-03 / SC-12.
All economic activation gates default closed.
"""

from dataclasses import dataclass
import os


def _enabled(name: str) -> bool:
    return os.getenv(name, "false").strip().lower() == "true"


@dataclass(frozen=True)
class SourceCoinFeatureGates:
    mint_enabled: bool = False
    burn_enabled: bool = False
    production_economy_enabled: bool = False

    @classmethod
    def from_environment(cls) -> "SourceCoinFeatureGates":
        return cls(
            mint_enabled=_enabled("SOURCE_COIN_MINT_ENABLED"),
            burn_enabled=_enabled("SOURCE_COIN_BURN_ENABLED"),
            production_economy_enabled=_enabled("SOURCE_COIN_PRODUCTION_ECONOMY_ENABLED"),
        )

    def assert_production_closed(self) -> None:
        if self.mint_enabled or self.burn_enabled or self.production_economy_enabled:
            raise RuntimeError(
                "Source Coin production economic capabilities require SC-E12 authorization"
            )


DEFAULT_GATES = SourceCoinFeatureGates()
