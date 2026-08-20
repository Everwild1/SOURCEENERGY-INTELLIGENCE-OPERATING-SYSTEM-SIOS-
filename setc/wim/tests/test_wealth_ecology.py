import unittest
from decimal import Decimal
from setc.wim.wealth_ecology import ImpactCorrection, ImpactMeasurement, MeasurementKind, MetricDefinition, MetricFamily, WealthEcologyLoop

DEF=MetricDefinition("WEM-JOBS-001","Jobs",MetricFamily.JOBS,"1.0","jobs")
class WealthEcologyTests(unittest.TestCase):
    def test_verified_measurement_requires_evidence_dedup_and_confidence(self):
        m=ImpactMeasurement(DEF,"txn:1",Decimal("12"),MeasurementKind.VERIFIED,"evidence:1","txn:1:jobs",Decimal("0.95")); m.require_reportable()
    def test_verified_low_confidence_fails_closed(self):
        with self.assertRaises(ValueError): ImpactMeasurement(DEF,"txn:1",Decimal("12"),MeasurementKind.VERIFIED,"e:1","d:1",Decimal("0.5")).require_reportable()
    def test_estimate_is_explicitly_distinct_from_verified(self):
        self.assertNotEqual(MeasurementKind.ESTIMATE,MeasurementKind.VERIFIED)
    def test_measurement_creates_no_economic_authority(self):
        m=ImpactMeasurement(DEF,"txn:1",Decimal("12"),MeasurementKind.OBSERVED,"e:1","d:1"); self.assertFalse(m.creates_financial_or_economic_authority)
    def test_correction_preserves_history(self):
        c=ImpactCorrection("impact:old","impact:new","method correction","evidence:2"); self.assertTrue(c.preserves_history)
    def test_correction_cannot_self_reference(self):
        with self.assertRaises(ValueError): ImpactCorrection("impact:1","impact:1","reason","evidence")
    def test_end_to_end_wealth_ecology_loop(self):
        loop=WealthEcologyLoop("research:1","commercialization:1","market:1","transaction:1","impact:1","research:feedback:1"); loop.require_complete()
    def test_incomplete_loop_fails_closed(self):
        with self.assertRaises(ValueError): WealthEcologyLoop("research:1","commercialization:1","market:1","transaction:1","impact:1","").require_complete()
if __name__=="__main__": unittest.main()
