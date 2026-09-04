from __future__ import annotations

import unittest
from dataclasses import replace
from datetime import datetime, timezone
import json
from pathlib import Path

from setc.wnf7 import (
    ADAPTER_DEFINITIONS,
    ADAPTER_VERSION,
    ALL_COMPONENTS,
    ALL_DIMENSIONS,
    COMPONENT_ADAPTERS,
    COMPONENT_BINDINGS,
    AssessmentRequest,
    AutomatedState,
    ComponentCode,
    ComponentAssessmentSubmission,
    ConsequenceClass,
    DecisionEligibility,
    Dimension,
    DimensionObservation,
    DimensionState,
    SupabaseWNF7Repository,
    WNF7AssessmentService,
    WNF7ComponentGateway,
    WNF7ContractError,
    component_binding,
    component_adapter,
    evaluate_assessment,
)


NOW = datetime(2026, 9, 4, 19, 0, tzinfo=timezone.utc)


def observations(**states: DimensionState) -> tuple[DimensionObservation, ...]:
    return tuple(
        DimensionObservation(
            dimension=dimension,
            status=states.get(dimension.value, DimensionState.PASS),
            finding=f"{dimension.value} synthetic control finding.",
            evidence_refs=(f"synthetic://wnf7/{dimension.value.lower()}",),
            reviewed_at=NOW,
        )
        for dimension in ALL_DIMENSIONS
    )


def request(
    component: ComponentCode = ComponentCode.SETC,
    *,
    assessment_id: str = "WNF7-TEST-001",
    idempotency_key: str = "IDEM-WNF7-001",
    authority_ref: str | None = "synthetic://authority/current",
    dimension_observations: tuple[DimensionObservation, ...] | None = None,
    interpretive_meaning: str | None = None,
    operation_code: str | None = None,
) -> AssessmentRequest:
    adapter = component_adapter(component)
    return adapter.prepare(
        ComponentAssessmentSubmission(
            assessment_id=assessment_id,
            operation_code=operation_code or adapter.default_operation_code,
            subject_ref="synthetic://subject/001",
            correlation_id="CORR-WNF7-001",
            idempotency_key=idempotency_key,
            observed_at=NOW,
            authority_ref=authority_ref,
            operational_reason="Exercise the WNF-7 runtime contract.",
            interpretive_meaning=interpretive_meaning,
            observations=dimension_observations or observations(),
            metadata={"classification": "SYNTHETIC_NON_PRODUCTION"},
        )
    )


class Result:
    def __init__(self, data):
        self.data = data


class Query:
    def __init__(self, client, table):
        self.client = client
        self.table_name = table
        self.operation = None
        self.payload = None
        self.filters = []

    def select(self, columns="*"):
        self.operation = ("select", columns)
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def insert(self, payload):
        self.operation = ("insert", None)
        self.payload = dict(payload)
        return self

    def execute(self):
        self.client.calls.append(
            (self.client.schema_name, self.table_name, self.operation, self.payload, self.filters)
        )
        if self.operation[0] == "select":
            rows = self.client.records
            for column, value in self.filters:
                rows = [row for row in rows if row.get(column) == value]
            return Result(rows)
        self.client.records.append(dict(self.payload))
        return Result([dict(self.payload)])


class Schema:
    def __init__(self, client):
        self.client = client

    def table(self, name):
        return Query(self.client, name)


class FakeClient:
    def __init__(self):
        self.schema_name = None
        self.calls = []
        self.records = []

    def schema(self, name):
        self.schema_name = name
        return Schema(self)


class WNF7RuntimeTests(unittest.TestCase):
    def test_all_eight_components_have_seven_specific_bindings(self):
        self.assertEqual(set(COMPONENT_BINDINGS), set(ALL_COMPONENTS))
        control_refs = set()
        operational_focuses = set()
        for binding in COMPONENT_BINDINGS.values():
            self.assertEqual(set(binding.dimensions), set(ALL_DIMENSIONS))
            for rule in binding.dimensions.values():
                control_refs.add(rule.control_ref)
                operational_focuses.add(rule.operational_focus)
        self.assertEqual(len(control_refs), 56)
        self.assertEqual(len(operational_focuses), 56)

    def test_all_eight_components_use_the_shared_evaluator(self):
        for component in ALL_COMPONENTS:
            with self.subTest(component=component.value):
                result = evaluate_assessment(request(component))
                self.assertEqual(result.component_code, component)
                self.assertEqual(result.automated_state, AutomatedState.PASS)
                self.assertFalse(result.may_execute)

    def test_all_eight_component_adapters_are_pilot_only_and_non_executing(self):
        self.assertEqual(set(ADAPTER_DEFINITIONS), set(ALL_COMPONENTS))
        self.assertEqual(set(COMPONENT_ADAPTERS), set(ALL_COMPONENTS))
        operation_pairs = set()
        for component, adapter in COMPONENT_ADAPTERS.items():
            definition = adapter.definition
            self.assertEqual(definition.component_code, component)
            self.assertEqual(definition.adapter_version, ADAPTER_VERSION)
            self.assertEqual(len(definition.operations), 3)
            self.assertFalse(definition.production_authorized)
            self.assertFalse(definition.external_side_effects)
            self.assertFalse(adapter.may_execute)
            operation_pairs.update(
                (component, operation_code) for operation_code in definition.operations
            )
        self.assertEqual(len(operation_pairs), 24)

    def test_gateway_routes_every_component_through_its_registered_adapter(self):
        client = FakeClient()
        gateway = WNF7ComponentGateway(WNF7AssessmentService(SupabaseWNF7Repository(client)))
        for index, component in enumerate(ALL_COMPONENTS, start=1):
            adapter = component_adapter(component)
            submission = ComponentAssessmentSubmission(
                assessment_id=f"WNF7-GATEWAY-{index:02d}",
                operation_code=adapter.default_operation_code,
                subject_ref=f"synthetic://subject/{component.value.lower()}",
                correlation_id=f"CORR-WNF7-{index:02d}",
                idempotency_key=f"IDEM-WNF7-{index:02d}",
                observed_at=NOW,
                authority_ref="synthetic://authority/current",
                operational_reason="Exercise the registered component entry point.",
                observations=observations(),
            )
            receipt = gateway.assess(component, submission)
            self.assertEqual(receipt.result.component_code, component)
            self.assertEqual(receipt.result.adapter_code, adapter.definition.adapter_code)
            self.assertFalse(receipt.may_execute)
        self.assertEqual(len(client.records), 8)

    def test_adapter_derives_consequence_and_rejects_impact_downgrade(self):
        prepared = request(
            ComponentCode.SOURCECOIN,
            operation_code="TRANSFER_ELIGIBILITY",
        )
        self.assertEqual(prepared.consequence_class, ConsequenceClass.CONSEQUENTIAL)
        downgraded = replace(prepared, consequence_class=ConsequenceClass.ADVISORY)
        with self.assertRaisesRegex(WNF7ContractError, "requires consequence class"):
            evaluate_assessment(downgraded)

    def test_adapter_rejects_commands_side_effects_and_secret_metadata(self):
        adapter = component_adapter(ComponentCode.SIOS)
        base = dict(
            assessment_id="WNF7-ADAPTER-SAFETY",
            operation_code=adapter.default_operation_code,
            subject_ref="synthetic://subject/safety",
            correlation_id="CORR-WNF7-SAFETY",
            idempotency_key="IDEM-WNF7-SAFETY",
            observed_at=NOW,
            operational_reason="Reject unsafe adapter material.",
            observations=observations(),
        )
        with self.assertRaisesRegex(WNF7ContractError, "execution command"):
            ComponentAssessmentSubmission(**base, execution_command={"action": "execute"})
        with self.assertRaisesRegex(WNF7ContractError, "external side effect"):
            ComponentAssessmentSubmission(**base, external_side_effect_requested=True)
        with self.assertRaisesRegex(WNF7ContractError, "prohibited"):
            ComponentAssessmentSubmission(**base, metadata={"nested": {"private-key": "x"}})

    def test_adapter_rejects_unknown_operation(self):
        adapter = component_adapter(ComponentCode.SOURCECUBE)
        submission = ComponentAssessmentSubmission(
            assessment_id="WNF7-UNKNOWN-OP",
            operation_code="EXECUTE_TRANSACTION",
            subject_ref="synthetic://subject/unknown",
            correlation_id="CORR-WNF7-UNKNOWN",
            idempotency_key="IDEM-WNF7-UNKNOWN",
            observed_at=NOW,
            operational_reason="Reject an unregistered operation.",
            observations=observations(),
        )
        with self.assertRaisesRegex(WNF7ContractError, "unsupported SOURCECUBE"):
            adapter.prepare(submission)

    def test_sourcecoin_and_sourceblock_boundaries_remain_non_executing(self):
        sourcecoin = component_binding(ComponentCode.SOURCECOIN)
        sourceblock = component_binding(ComponentCode.SOURCEBLOCK)
        self.assertIn("no minting", sourcecoin.execution_boundary.lower())
        self.assertIn("cannot manufacture ownership", sourceblock.execution_boundary.lower())

    def test_all_pass_is_only_eligible_for_human_decision(self):
        result = evaluate_assessment(request())
        self.assertEqual(result.automated_state, AutomatedState.PASS)
        self.assertEqual(
            result.decision_eligibility,
            DecisionEligibility.ELIGIBLE_FOR_HUMAN_DECISION,
        )
        self.assertTrue(result.human_review_required)
        self.assertIsNone(result.execution_command)
        self.assertFalse(result.may_execute)
        self.assertEqual(len(result.dimension_results), 7)

    def test_fear_uncertainty_is_a_hard_block(self):
        result = evaluate_assessment(
            request(dimension_observations=observations(FEAR=DimensionState.REVIEW))
        )
        self.assertEqual(result.automated_state, AutomatedState.BLOCKED)
        self.assertEqual(result.decision_eligibility, DecisionEligibility.NOT_ELIGIBLE)
        self.assertEqual(result.blocking_dimensions, (Dimension.FEAR,))

    def test_claimed_fear_pass_without_authority_fails_closed(self):
        result = evaluate_assessment(request(authority_ref=None))
        self.assertEqual(result.automated_state, AutomatedState.BLOCKED)
        fear = result.dimension_results[0]
        self.assertEqual(fear.status, DimensionState.BLOCKED)
        self.assertIn("Authority reference missing", fear.finding)

    def test_non_blocking_uncertainty_is_simulation_only(self):
        result = evaluate_assessment(
            request(dimension_observations=observations(KNOWLEDGE=DimensionState.REVIEW))
        )
        self.assertEqual(result.automated_state, AutomatedState.REVIEW)
        self.assertEqual(result.decision_eligibility, DecisionEligibility.SIMULATION_ONLY)
        self.assertEqual(result.review_dimensions, (Dimension.KNOWLEDGE,))

    def test_exactly_seven_dimensions_are_required(self):
        with self.assertRaisesRegex(WNF7ContractError, "seven dimensions"):
            request(dimension_observations=observations()[:-1])

    def test_not_applicable_requires_reason_and_authority(self):
        with self.assertRaisesRegex(WNF7ContractError, "requires a reason"):
            DimensionObservation(
                dimension=Dimension.WISDOM,
                status=DimensionState.NOT_APPLICABLE,
                finding="Not applicable was asserted.",
                evidence_refs=("synthetic://evidence/na",),
                reviewed_at=NOW,
            )

    def test_interpretive_meaning_cannot_change_operational_posture(self):
        first = evaluate_assessment(request(interpretive_meaning="First interpretation."))
        second = evaluate_assessment(
            request(
                assessment_id="WNF7-TEST-002",
                idempotency_key="IDEM-WNF7-002",
                interpretive_meaning="Different interpretation.",
            )
        )
        self.assertEqual(first.automated_state, second.automated_state)
        self.assertEqual(first.decision_eligibility, second.decision_eligibility)
        self.assertNotEqual(first.input_sha256, second.input_sha256)

    def test_profile_component_mismatch_is_rejected(self):
        invalid = AssessmentRequest(
            assessment_id="WNF7-TEST-MISMATCH",
            component_code=ComponentCode.SOURCECUBE,
            profile_code="SETC-PROFILE-7D-001",
            adapter_code=component_adapter(ComponentCode.SOURCECUBE).definition.adapter_code,
            adapter_version=ADAPTER_VERSION,
            operation_code="CONTEXT_CLASSIFICATION",
            subject_ref="synthetic://subject/mismatch",
            correlation_id="CORR-WNF7-MISMATCH",
            idempotency_key="IDEM-WNF7-MISMATCH",
            consequence_class=ConsequenceClass.ADVISORY,
            observed_at=NOW,
            authority_ref="synthetic://authority/current",
            operational_reason="Reject a profile mismatch.",
            observations=observations(),
        )
        with self.assertRaisesRegex(WNF7ContractError, "does not govern"):
            evaluate_assessment(invalid)

    def test_result_contains_every_required_assessment_envelope_field(self):
        schema_path = Path(__file__).parents[1] / "docs/wnf7/assessment-envelope.schema.json"
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        payload = evaluate_assessment(request()).to_dict()
        self.assertTrue(set(schema["required"]).issubset(payload))
        self.assertEqual(len(payload["dimensions"]), 7)
        self.assertEqual(len(payload["dimension_results"]), 7)
        self.assertEqual(payload["consequence_class"], "OPERATIONAL")
        self.assertTrue(payload["human_review_required"])
        self.assertIsNone(payload["execution_command"])
        self.assertRegex(payload["input_sha256"], r"^[0-9a-f]{64}$")
        self.assertRegex(payload["output_sha256"], r"^[0-9a-f]{64}$")

    def test_supabase_repository_is_private_append_only_and_null_command(self):
        client = FakeClient()
        repository = SupabaseWNF7Repository(client)
        self.assertEqual(client.schema_name, "wnf7")
        assessment_request = request()
        result = evaluate_assessment(assessment_request)
        record = repository.append(assessment_request, result)
        self.assertEqual(record["execution_command"], None)
        self.assertTrue(record["human_review_required"])
        self.assertEqual(len(record["dimension_results"]), 7)
        self.assertEqual(record["adapter_code"], assessment_request.adapter_code)
        self.assertEqual(record["operation_code"], assessment_request.operation_code)
        self.assertFalse(hasattr(repository, "update"))
        self.assertFalse(hasattr(repository, "delete"))

    def test_service_replays_identical_idempotent_input_without_second_insert(self):
        client = FakeClient()
        service = WNF7AssessmentService(SupabaseWNF7Repository(client))
        assessment_request = request()
        first = service.assess(assessment_request)
        second = service.assess(assessment_request)
        insert_calls = [call for call in client.calls if call[2][0] == "insert"]
        self.assertFalse(first.replayed)
        self.assertTrue(second.replayed)
        self.assertEqual(len(insert_calls), 1)

    def test_idempotency_conflict_is_rejected(self):
        client = FakeClient()
        service = WNF7AssessmentService(SupabaseWNF7Repository(client))
        service.assess(request())
        changed = request(
            assessment_id="WNF7-TEST-CHANGED",
            interpretive_meaning="Changed input under reused idempotency key.",
        )
        with self.assertRaisesRegex(WNF7ContractError, "different assessment input"):
            service.assess(changed)


if __name__ == "__main__":
    unittest.main()
