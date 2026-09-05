"""Canonical WNF-7 bindings for the eight SourceEnergy components."""

from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType
from typing import Mapping

from .models import ALL_DIMENSIONS, ComponentCode, Dimension, WNF7ContractError


_DIMENSION_OWNERS: Mapping[Dimension, str] = MappingProxyType(
    {
        Dimension.FEAR: "SETC_OWNER",
        Dimension.PRESENCE: "TECH_AUTHORITY",
        Dimension.WISDOM: "PILOT_OWNER",
        Dimension.KNOWLEDGE: "QA_LEAD",
        Dimension.UNDERSTANDING: "QA_LEAD",
        Dimension.COUNSEL: "KNOWLEDGE_GOVERNOR",
        Dimension.MIGHT_POWER: "SOURCECUBE_OWNER",
    }
)


@dataclass(frozen=True, slots=True)
class DimensionBinding:
    control_ref: str
    owner_role: str
    operational_focus: str


@dataclass(frozen=True, slots=True)
class ComponentBinding:
    component_code: ComponentCode
    profile_code: str
    operational_scope: str
    execution_boundary: str
    dimensions: Mapping[Dimension, DimensionBinding]

    def __post_init__(self) -> None:
        if set(self.dimensions) != set(ALL_DIMENSIONS):
            raise WNF7ContractError("component binding must map all seven dimensions")


def _component_binding(
    component: ComponentCode,
    profile_code: str,
    operational_scope: str,
    execution_boundary: str,
    focuses: tuple[str, str, str, str, str, str, str],
) -> ComponentBinding:
    dimension_bindings = {
        dimension: DimensionBinding(
            control_ref=f"WNF7-{component.value}-{ordinal:02d}",
            owner_role=_DIMENSION_OWNERS[dimension],
            operational_focus=focus,
        )
        for ordinal, (dimension, focus) in enumerate(zip(ALL_DIMENSIONS, focuses), start=1)
    }
    return ComponentBinding(
        component_code=component,
        profile_code=profile_code,
        operational_scope=operational_scope,
        execution_boundary=execution_boundary,
        dimensions=MappingProxyType(dimension_bindings),
    )


_BINDINGS = (
    _component_binding(
        ComponentCode.SETC,
        "SETC-PROFILE-7D-001",
        "Authority, evidence, policy, review routing, and bounded execution control.",
        "SETC cannot manufacture external authority or approve its own consequential action.",
        (
            "Resolve the governing authority, rule, scope, expiry, and jurisdiction before policy evaluation.",
            "Bind the canonical actor, organization, governed object, request, provenance, and correlation identity.",
            "Test the proposed decision against declared purpose, architecture, stewardship, alternatives, and durable value.",
            "Classify evidence, freshness, confidence, contradiction, and the line between fact, inference, and interpretation.",
            "Assess jurisdiction, affected parties, dependencies, uncertainty, asymmetry, and downstream consequences.",
            "Select the accountable approval, dissent, exception, appeal, and escalation route without self-approval.",
            "Enforce capability allowlists, confirmation, idempotency, reversibility, receipts, and immutable audit evidence.",
        ),
    ),
    _component_binding(
        ComponentCode.SOURCECUBE,
        "SOURCECUBE-PROFILE-7D-001",
        "Context classification, evidence lineage, reproducible advisory analysis, and orchestration planning.",
        "SourceCube is advisory and cannot authorize transactions or mutate authoritative systems.",
        (
            "Require a valid SETC policy decision and delegated orchestration scope before preparing any plan.",
            "Resolve source records, versions, time, place, provenance, correlation, and causation for the working context.",
            "Choose an advisory plan that remains aligned to the approved purpose and bounded architecture.",
            "Cite attributable sources and expose freshness, confidence, conflicts, calculations, inference, and interpretation.",
            "Model jurisdiction, affected parties, asymmetric effects, uncertainty, dependencies, and failure modes.",
            "Recommend accountable reviewers, alternatives, approvals, and escalation without presenting advice as approval.",
            "Emit a null execution command and require an independently authorized broker, idempotency key, and receipt.",
        ),
    ),
    _component_binding(
        ComponentCode.CODEX_VERITAS,
        "CODEX-VERITAS-PROFILE-7D-001",
        "Claim provenance, truth state, confidence, contradiction, supersession, and meaning separation.",
        "Codex Veritas cannot turn interpretation into evidence, certainty, endorsement, authority, or external finality.",
        (
            "Bind every claim to the applicable canon, source authority, permitted scope, and explicit limitation.",
            "Preserve canonical claim identity, provenance, authorship, version, timestamp, and supersession lineage.",
            "Separate enduring meaning and purpose from unsupported scientific, legal, commercial, or operational assertion.",
            "Classify retrieved evidence, calculation, inference, policy rule, interpretation, and human judgment distinctly.",
            "Expose context, contradiction, uncertainty, asymmetry, affected audiences, and the effect of superseding evidence.",
            "Route disputed or sensitive claims to qualified reviewers and preserve dissent, correction, and appeal history.",
            "Permit only governed publication or supersession; never manufacture truth, authority, ownership, or finality.",
        ),
    ),
    _component_binding(
        ComponentCode.SOURCEONE,
        "SOURCEONE-PROFILE-7D-001",
        "Human-facing context, explanation, warnings, approvals, and outcome visibility.",
        "SourceOne cannot hide uncertainty, bypass blocked gates, or convert an interface action into authority.",
        (
            "Show authority posture, policy limits, and denials before enabling a human-facing action.",
            "Bind the human, session, device context, governed resource, version, and correlation reference.",
            "Explain purpose, expected outcome, stewardship implications, constraints, and meaningful alternatives.",
            "Display sources, freshness, confidence, contradictions, assumptions, and unknowns in decision context.",
            "Explain jurisdiction, accessibility needs, affected parties, material risks, and downstream consequences.",
            "Capture explicit human approvals and surface reviewer identity, dissent, exception, and escalation routes.",
            "Disable prohibited or replayed actions and require confirmation plus an authoritative completion receipt.",
        ),
    ),
    _component_binding(
        ComponentCode.SIOS,
        "SIOS-PROFILE-7D-001",
        "Governed APIs, events, state machines, observability, enforcement, and cross-domain confirmation.",
        "SIOS cannot aggregate missing authority or represent an unconfirmed external effect as complete.",
        (
            "Enforce authority and policy at every API, event, workflow, and state-transition boundary.",
            "Propagate canonical identifiers, versions, provenance, correlation, causation, tenant, time, and place.",
            "Select a bounded workflow consistent with approved system architecture, purpose, and stewardship constraints.",
            "Preserve attributable evidence references, telemetry, truth classification, audit state, and data lineage.",
            "Evaluate cross-domain dependencies, jurisdiction, affected parties, uncertainty, failure modes, and recovery impact.",
            "Route review tasks, exceptions, approvals, dissent, and escalation while prohibiting service self-approval.",
            "Enforce state machines, idempotency, outbox discipline, step-up confirmation, receipts, rollback, and audit.",
        ),
    ),
    _component_binding(
        ComponentCode.SIDEKICK_OEL,
        "SIDEKICK-OEL-PROFILE-7D-001",
        "Authorized intent translated into accountable work, evidence, escalation, and outcome review.",
        "Sidekick OEL cannot exceed delegated authority, OEL control level, confirmation, or SETC approval.",
        (
            "Accept only an authenticated, delegated work instruction whose role, scope, limits, and expiry are valid.",
            "Bind task, accountable owner, organization, work package, version, schedule, provenance, and correlation.",
            "Translate intent into scoped outcomes, resources, constraints, acceptance criteria, and reversible alternatives.",
            "Collect attributable status, assumptions, work products, completion evidence, quality results, and exceptions.",
            "Expose dependencies, workload, affected teams, jurisdiction, operational risk, and consequence asymmetry.",
            "Request supervisor or specialist review and escalate conflicts, missing approvals, dissent, and blockers.",
            "Perform only allowlisted reversible work within control level and preserve confirmation and outcome receipts.",
        ),
    ),
    _component_binding(
        ComponentCode.SOURCECOIN,
        "SOURCECOIN-PROFILE-7D-001",
        "Economic eligibility and governance signals for SourceCoin-related records.",
        "WNF-7 provides no minting, transfer, custody, valuation, redemption, burn, or settlement authority.",
        (
            "Require independent economic, legal, treasury, compliance, and governance authority for the requested scope.",
            "Bind participant, account, asset, obligation, network, ledger reference, provenance, and idempotency identity.",
            "Test economic purpose, stewardship, reserve impact, incentives, alternatives, and long-horizon value.",
            "Verify valuation sources, ledger evidence, custody evidence, balances, obligations, and external confirmations.",
            "Assess jurisdiction, tax, sanctions, market, liquidity, custody, counterparty, and participant consequences.",
            "Require accountable treasury, compliance, custody, risk, and human approvals with an escalation route.",
            "Return eligibility only; mint, transfer, burn, redeem, custody, valuation, and settlement remain disabled.",
        ),
    ),
    _component_binding(
        ComponentCode.SOURCEBLOCK,
        "SOURCEBLOCK-PROFILE-7D-001",
        "A bounded project, activity, or value-producing unit carrying a seven-dimensional lifecycle profile.",
        "A SourceBlock record cannot manufacture ownership, authority, valuation, completion, or external finality.",
        (
            "Bind the block to an authorized sponsor, charter, delegated decision rights, scope, and lifecycle gate.",
            "Assign canonical block, project, activity, owner, location, version, provenance, and lifecycle identity.",
            "Validate purpose, value thesis, resource use, stewardship, alternatives, and closure obligations.",
            "Attach attributable milestone, metric, cost, risk, deliverable, provenance, and outcome evidence.",
            "Map stakeholders, jurisdictions, dependencies, uncertainty, externalities, and asymmetric consequences.",
            "Route stage gates, change requests, exceptions, acceptance, closure, dissent, and escalation to accountable humans.",
            "Allow only bounded lifecycle transitions with idempotency and receipts; never assert ownership, value, or finality.",
        ),
    ),
)


COMPONENT_BINDINGS: Mapping[ComponentCode, ComponentBinding] = MappingProxyType(
    {binding.component_code: binding for binding in _BINDINGS}
)


def component_binding(component_code: ComponentCode | str) -> ComponentBinding:
    try:
        return COMPONENT_BINDINGS[ComponentCode(component_code)]
    except (KeyError, ValueError) as exc:
        raise WNF7ContractError(f"unsupported WNF-7 component: {component_code}") from exc
