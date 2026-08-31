from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import unittest

from setc.sourcecube.momentum import (
    GovernanceSeverity,
    MomentumObservation,
    MomentumSignal,
    ThresholdPolicy,
    evaluate_momentum_unwind,
)


ROOT = Path(__file__).resolve().parents[3]


def observation(**overrides: object) -> MomentumObservation:
    values: dict[str, object] = {
        "observed_at": datetime(2026, 8, 31, 12, 0, tzinfo=timezone.utc),
        "largest_daily_decline_pct": 0.0,
        "vix": 20.0,
        "bearish_rsi_divergence": False,
        "abnormal_volume": False,
        "ten_year_yield_change_bps": 0.0,
        "sharp_usd_strength": False,
        "source_ids": ("cboe-vix",),
        "source_links": {"cboe-vix": "https://www.cboe.com/tradable_products/vix/"},
    }
    values.update(overrides)
    return MomentumObservation(**values)  # type: ignore[arg-type]


class ThresholdPolicyTests(unittest.TestCase):
    def test_repository_policy_loads(self) -> None:
        path = ROOT / "contracts/sourcecube/momentum-unwind-policy.v1.json"
        policy = ThresholdPolicy.from_mapping(json.loads(path.read_text()))
        self.assertEqual(policy.alert_min_signals, 2)
        self.assertEqual(policy.red_min_signals, 3)
        self.assertEqual(policy.autonomy_ceiling, "C2")

    def test_policy_rejects_autonomy_expansion(self) -> None:
        with self.assertRaisesRegex(ValueError, "capped at C2"):
            ThresholdPolicy(autonomy_ceiling="C3")


class MomentumEvaluationTests(unittest.TestCase):
    def test_one_signal_does_not_alert(self) -> None:
        result = evaluate_momentum_unwind(observation(vix=26.0))
        self.assertFalse(result.alert_eligible)
        self.assertEqual(result.severity, GovernanceSeverity.NONE)

    def test_exactly_two_signals_create_amber_inference(self) -> None:
        result = evaluate_momentum_unwind(
            observation(largest_daily_decline_pct=5.0, vix=25.1)
        )
        self.assertTrue(result.alert_eligible)
        self.assertEqual(result.severity, GovernanceSeverity.AMBER)
        self.assertEqual(
            result.triggered_signals,
            (MomentumSignal.DAILY_DECLINE, MomentumSignal.VIX_ABOVE_THRESHOLD),
        )
        self.assertEqual(result.information_stage, "inference")
        self.assertFalse(result.decision_eligible)

    def test_three_signals_create_red_inference(self) -> None:
        result = evaluate_momentum_unwind(
            observation(vix=30.0, abnormal_volume=True, sharp_usd_strength=True)
        )
        self.assertEqual(result.severity, GovernanceSeverity.RED)
        self.assertEqual(result.trigger_count, 3)

    def test_strict_boundaries_do_not_trigger_at_vix_25_or_15_bps(self) -> None:
        result = evaluate_momentum_unwind(
            observation(vix=25.0, ten_year_yield_change_bps=15.0)
        )
        self.assertEqual(result.trigger_count, 0)

    def test_replay_is_deterministic(self) -> None:
        item = observation(vix=26.0, abnormal_volume=True)
        first = evaluate_momentum_unwind(item)
        second = evaluate_momentum_unwind(item)
        self.assertEqual(first.idempotency_key, second.idempotency_key)
        self.assertEqual(first.content_sha256, second.content_sha256)

    def test_source_evidence_is_required(self) -> None:
        with self.assertRaisesRegex(ValueError, "source links missing"):
            observation(source_ids=("cboe-vix", "ust-10y"))


if __name__ == "__main__":
    unittest.main()
