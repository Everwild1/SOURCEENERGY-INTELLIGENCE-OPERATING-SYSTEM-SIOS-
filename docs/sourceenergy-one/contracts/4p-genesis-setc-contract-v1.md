# 4P Genesis → SETC Contract v1

Status: proposed governed contract

## Decision

Purpose, Product, People, and Profit (4P) are a native economic ontology of the SETC pathway. Genesis does not define the ontology. Genesis carries the human-approved, subject-specific 4P baseline that SETC and SourceCube may subsequently interpret and orchestrate under governance.

## Authority separation

- SourceEnergy One synthesizes the subject-specific 4P candidate from governed evidence.
- Human confirmation is mandatory before the 4P profile can enter authoritative Genesis.
- Genesis immutably attests the approved 4P baseline, its provenance, evidence references, versions, and approval attestation.
- SETC natively understands the four dimensions and must not depend on free-form Genesis text to discover them.
- SourceCube may evaluate changes, relationships, opportunities, risks, and economic pathways against the Genesis baseline, but cannot silently rewrite Genesis.
- Material 4P changes require governed review and a superseding Genesis record.

## 4P dimensions

### Purpose
Why the subject or undertaking exists and the value thesis it intends to advance. Purpose must reference governed Purpose Discovery / Purpose Profile evidence rather than embed protected raw narrative.

### Product
What is created, delivered, operated, researched, licensed, financed, or otherwise brought into the Wealth Ecology. Product should bind to approved MVP/artifact evidence where applicable.

### People
Who creates, governs, participates in, is affected by, or benefits from the undertaking. People is broader than identity: it includes accountable actors, organizations, stakeholders, beneficiaries, communities, and governed participation relationships.

### Profit
How economic sustainability and value capture are expected to work. Profit includes revenue/value-capture logic, capital sustainability, reinvestment, distributions, reserves, and other governed economic outcomes. It is not an authorization to transact, promise returns, or execute financial activity.

## Genesis payload

The authoritative package includes `economic_4p_profile` with exactly four governed dimensions: `purpose`, `product`, `people`, and `profit`. Each dimension carries:

- `statement`: approved concise baseline;
- `evidence_refs`: one or more governed references;
- `source_hash`: provenance hash/reference;
- `version`: dimension version.

The profile additionally carries `version`, `approved_by`, and `approval_attestation`.

The canonical Genesis payload explicitly records `human_approved=true` after the Genesis Experience has passed the human-approval gate.

## SETC invariant

SETC implementations must model 4P as first-class typed dimensions. A Genesis package supplies the initial authoritative values; absence of a valid 4P baseline is a fail-closed condition for a new SETC Genesis pathway after this contract becomes effective.

SETC may derive metrics, relationships, economic clusters, organizations, products/services, opportunities, and Wealth Ecology intelligence from the 4P baseline, but consequential execution remains subject to SourceEnergy One policy, human authorization, SIOS adapter controls, and auditable receipts.

## Synthetic Genesis

Synthetic/staging Genesis may exercise the schema using clearly marked non-production evidence and actor references. It must never be interpreted as a real participant's human approval, economic representation, entitlement, or financial authorization.
