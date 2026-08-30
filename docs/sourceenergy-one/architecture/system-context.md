# SourceEnergy One - System Context

## System context

```text
Human / Authorized Agent / Device
        |
        v
SourceEnergy One Experience Layer
        |
        v
Identity + Session + Consent Context
        |
        v
SourceCube Orchestration Layer
   |        |        |
   |        |        +--> Evidence / Knowledge Retrieval
   |        +-----------> Policy + Governance Evaluation
   +--------------------> Workflow / Domain Routing
        |
        v
Human Authorization Gate (when consequential)
        |
        v
SIOS Domain Services and Adapters
        |
        +--> Supabase authoritative operational datasets
        +--> SETC / Genesis provenance services
        +--> Institutional systems and approved external integrations
        |
        v
Execution + Audit + Observability
```

## Genesis trust chain

```text
Purpose Discovery responses (protected testimony)
 -> Codex 24 candidate interpretation
 -> MVP + 100-Year Impact draft
 -> Human review / edit / reject / approve
 -> Approved Genesis package
 -> SETC Genesis provenance record
 -> SourceCube authorized context
```

## Trust boundaries

### TB-1 Human testimony
User-authored Purpose Discovery responses are source evidence. AI-generated interpretations must never overwrite them.

### TB-2 Codex 24 interpretation
Codex 24 outputs are derived artifacts. They require explicit human confirmation before promotion into an approved Genesis package.

### TB-3 Genesis approval
Genesis is a provenance boundary. Approval records version, consent, evidence references and hashes. Sensitive narratives should remain protected outside immutable/public surfaces.

### TB-4 SourceCube orchestration
SourceCube may recommend, retrieve, route and prepare actions. It must evaluate identity, authorization, consent, policy and evidence before invoking domain services.

### TB-5 Consequential execution
Financial, legal, governance, identity, permission, external communication and other consequential actions require the applicable human/institutional authorization policy before execution.

## Core service contracts

- `identity-context`: authenticated principal, roles, organizations, delegated authority.
- `consent-context`: permitted purposes, scopes, retention and revocation state.
- `purpose-profile`: protected questionnaire evidence and versioning.
- `codex24-interpretation`: model/version/evidence-linked candidate synthesis.
- `impact-report`: MVP and 100-year impact artifact versions.
- `genesis-package`: approved, signed/versioned provenance payload.
- `sourcecube-plan`: proposed orchestration plan, evidence and policy evaluation.
- `authorization-decision`: approve/decline/defer/request-counsel with actor and timestamp.
- `execution-receipt`: downstream result and immutable/auditable correlation identifiers.

## Non-negotiable controls

- Least privilege and explicit authorization.
- Tenant/organization isolation.
- Encryption in transit and at rest.
- Row-level security where operational data is held in Supabase.
- No model provider receives unrestricted ecosystem data by default.
- Prompt/model/version provenance for derived artifacts.
- Idempotency for consequential commands.
- Append-only audit events for authorization and execution boundaries.
- Correlation IDs spanning SourceEnergy One, SourceCube, SIOS and SETC.
