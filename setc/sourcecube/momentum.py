"""SC-MUW-001 deterministic momentum-unwind signal gate.

The evaluator converts validated observations into a bounded inference. It cannot
create a decision, authorization, trade, hedge, or execution instruction.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from hashlib import sha256
import json
from math import isfinite
from typing import Any, Mapping, Sequence


class MomentumSignal(StrEnum):
    DAILY_DECLINE = "daily_decline"
    VIX_ABOVE_THRESHOLD = "vix_above_threshold"
    BEARISH_RSI_DIVERGENCE = "bearish_rsi_divergence"
    ABNORMAL_VOLUME = "abnormal_volume"
    TEN_YEAR_YIELD_SHOCK = "ten_year_yield_shock"
    SHARP_USD_STRENGTH = "sharp_usd_strength"


class GovernanceSeverity(StrEnum):
    NONE = "none"
    AMBER = "amber"
    RED = "red"


@dataclass(frozen=True, slots=True)
class ThresholdPolicy:
    policy_version: str = "sourcecube.momentum-unwind/1.0"
    daily_decline_pct: float = 5.0
    vix_strictly_above: float = 25.0
    ten_year_yield_change_bps_strictly_above: float = 15.0
    alert_min_signals: int = 2
    red_min_signals: int = 3
    autonomy_ceiling: str = "C2"

    def __post_init__(self) -> None:
        if not self.policy_version.strip():
            raise ValueError("policy_version is required")
        if self.daily_decline_pct <= 0:
            raise ValueError("daily_decline_pct must be positive")
        if self.vix_strictly_above <= 0:
            raise ValueError("vix_strictly_above must be positive")
        if self.ten_year_yield_change_bps_strictly_above <= 0:
            raise ValueError("ten_year_yield_change_bps_strictly_above must be positive")
        if self.alert_min_signals < 2:
            raise ValueError("alert_min_signals cannot be less than two")
        if self.red_min_signals <= self.alert_min_signals:
            raise ValueError("red_min_signals must exceed alert_min_signals")
        if self.autonomy_ceiling != "C2":
            raise ValueError("SC-MUW-001 is capped at C2")

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "ThresholdPolicy":
        thresholds = value["thresholds"]
        escalation = value["escalation"]
        governance = value["governance"]
        return cls(
            policy_version=str(value["policy_version"]),
            daily_decline_pct=float(thresholds["daily_decline_pct_gte"]),
            vix_strictly_above=float(thresholds["vix_gt"]),
            ten_year_yield_change_bps_strictly_above=float(
                thresholds["ten_year_yield_change_bps_gt"]
            ),
            alert_min_signals=int(escalation["alert_min_signals"]),
            red_min_signals=int(escalation["red_min_signals"]),
            autonomy_ceiling=str(governance["autonomy_ceiling"]),
        )


@dataclass(frozen=True, slots=True)
class MomentumObservation:
    observed_at: datetime
    largest_daily_decline_pct: float
    vix: float
    bearish_rsi_divergence: bool
    abnormal_volume: bool
    ten_year_yield_change_bps: float
    sharp_usd_strength: bool
    source_ids: Sequence[str]
    source_links: Mapping[str, str]

    def __post_init__(self) -> None:
        if self.observed_at.tzinfo is None:
            raise ValueError("observed_at must be timezone-aware")
        numeric_values = {
            "largest_daily_decline_pct": self.largest_daily_decline_pct,
            "vix": self.vix,
            "ten_year_yield_change_bps": self.ten_year_yield_change_bps,
        }
        for name, value in numeric_values.items():
            if not isfinite(value):
                raise ValueError(f"{name} must be finite")
        if self.largest_daily_decline_pct < 0:
            raise ValueError("largest_daily_decline_pct cannot be negative")
        if self.vix < 0:
            raise ValueError("vix cannot be negative")
        normalized_ids = tuple(source_id.strip() for source_id in self.source_ids)
        if not normalized_ids or any(not source_id for source_id in normalized_ids):
            raise ValueError("at least one non-empty source_id is required")
        if len(set(normalized_ids)) != len(normalized_ids):
            raise ValueError("source_ids must be unique")
        missing_links = set(normalized_ids).difference(self.source_links)
        if missing_links:
            raise ValueError(f"source links missing for: {sorted(missing_links)}")
        for source_id in normalized_ids:
            link = self.source_links[source_id]
            if not link.startswith("https://"):
                raise ValueError("source links must use https")
        object.__setattr__(self, "source_ids", normalized_ids)

    def canonical_payload(self) -> Mapping[str, Any]:
        return {
            "abnormal_volume": self.abnormal_volume,
            "bearish_rsi_divergence": self.bearish_rsi_divergence,
            "largest_daily_decline_pct": self.largest_daily_decline_pct,
            "observed_at": self.observed_at.isoformat(),
            "sharp_usd_strength": self.sharp_usd_strength,
            "source_ids": list(self.source_ids),
            "ten_year_yield_change_bps": self.ten_year_yield_change_bps,
            "vix": self.vix,
        }


@dataclass(frozen=True, slots=True)
class MomentumAssessment:
    policy_version: str
    observed_at: datetime
    triggered_signals: tuple[MomentumSignal, ...]
    severity: GovernanceSeverity
    alert_eligible: bool
    information_stage: str
    autonomy_ceiling: str
    decision_eligible: bool
    idempotency_key: str
    content_sha256: str
    causation_note: str

    def __post_init__(self) -> None:
        if self.information_stage != "inference":
            raise ValueError("momentum assessment must remain an inference")
        if self.decision_eligible:
            raise ValueError("momentum assessment cannot be decision eligible")
        if self.autonomy_ceiling != "C2":
            raise ValueError("momentum assessment cannot exceed C2")
        if self.alert_eligible is not (self.severity is not GovernanceSeverity.NONE):
            raise ValueError("severity and alert eligibility are inconsistent")

    @property
    def trigger_count(self) -> int:
        return len(self.triggered_signals)


def evaluate_momentum_unwind(
    observation: MomentumObservation,
    policy: ThresholdPolicy | None = None,
) -> MomentumAssessment:
    """Evaluate the configured signals without creating execution authority."""
    active_policy = policy or ThresholdPolicy()
    triggered: list[MomentumSignal] = []

    if observation.largest_daily_decline_pct >= active_policy.daily_decline_pct:
        triggered.append(MomentumSignal.DAILY_DECLINE)
    if observation.vix > active_policy.vix_strictly_above:
        triggered.append(MomentumSignal.VIX_ABOVE_THRESHOLD)
    if observation.bearish_rsi_divergence:
        triggered.append(MomentumSignal.BEARISH_RSI_DIVERGENCE)
    if observation.abnormal_volume:
        triggered.append(MomentumSignal.ABNORMAL_VOLUME)
    if (
        observation.ten_year_yield_change_bps
        > active_policy.ten_year_yield_change_bps_strictly_above
    ):
        triggered.append(MomentumSignal.TEN_YEAR_YIELD_SHOCK)
    if observation.sharp_usd_strength:
        triggered.append(MomentumSignal.SHARP_USD_STRENGTH)

    if len(triggered) >= active_policy.red_min_signals:
        severity = GovernanceSeverity.RED
    elif len(triggered) >= active_policy.alert_min_signals:
        severity = GovernanceSeverity.AMBER
    else:
        severity = GovernanceSeverity.NONE

    canonical = json.dumps(
        {
            "observation": observation.canonical_payload(),
            "policy_version": active_policy.policy_version,
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    digest = sha256(canonical).hexdigest()
    timestamp = observation.observed_at.isoformat()

    return MomentumAssessment(
        policy_version=active_policy.policy_version,
        observed_at=observation.observed_at,
        triggered_signals=tuple(triggered),
        severity=severity,
        alert_eligible=severity is not GovernanceSeverity.NONE,
        information_stage="inference",
        autonomy_ceiling=active_policy.autonomy_ceiling,
        decision_eligible=False,
        idempotency_key=f"sc-muw-001:{timestamp}:{digest[:16]}",
        content_sha256=digest,
        causation_note=(
            "The signals are contemporaneous observations and deterministic rule outputs; "
            "they do not by themselves establish a causal mechanism or authorize action."
        ),
    )
