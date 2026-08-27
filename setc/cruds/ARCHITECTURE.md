# CRUDS Universe Architecture Boundary

CRUDS Universe is the governed creative-economy, authorship, work-discovery and commercialization bounded context of the SourceEnergy Ecosystem.

## Mission

Preserve the recognizable CRUDS Universe identity — Creatives, Underwriters & Developers Universe; The Wall of Creatives; and the six creator archetypes — while converting the public experience into a governed operating layer for creator identity projection, works, provenance, opportunity discovery, commercialization and ecosystem intelligence.

## Canonical creator archetypes

1. Artist
2. Thinker
3. Adventurer
4. Maker
5. Producer
6. Dreamer

The archetypes are capability/discovery classifications. They do not create legal identity, intellectual-property ownership, professional licensing, accreditation, or financial authority.

## Authority map

| Concern | Authoritative domain | CRUDS posture |
|---|---|---|
| Institutional organization identity | SETC Organizations | Projection/reference only |
| Creator/person identity | Approved ecosystem identity authority | Projection/reference only |
| Creator archetype classification | CRUDS Universe | Authoritative for CRUDS discovery taxonomy |
| Creative work record and publication workflow | CRUDS Universe | Authoritative for CRUDS workflow state |
| Authorship/provenance evidence | Witness Grid / approved evidence authority | Request/reference/verification projection |
| Legal IP ownership or registration | Applicable legal/registration authority | Never conferred by CRUDS software |
| Commercial opportunity and market access | WIM Exchange | Request/projection/reference only |
| Settlement finality | Approved external financial rail | Reference/orchestration only |
| Source Coin ledger/economic effect | Source Coin domain services | Request/reference only |
| Wealth Ecology measurement | Governed ecosystem methodology/registry | Projection with provenance and methodology version |

## Fail-closed rules

1. A CRUDS creator profile never replaces authoritative legal or institutional identity.
2. Archetype assignment is descriptive and may be multi-valued; it confers no license, credential or legal status.
3. A work may be published without asserting verified authorship, but verification state must remain explicit.
4. A Witness Grid receipt/reference is evidence metadata; CRUDS must not fabricate cryptographic verification or legal ownership.
5. Market-access requests must cross the WIM Exchange integration boundary; CRUDS does not duplicate WIM opportunity, transaction, trade or settlement authority.
6. Source Coin request/reference never means settlement finality and CRUDS cannot mutate Source Coin balances, supply, treasury or ledger state.
7. Provenance corrections preserve history rather than destructively rewriting prior evidence.
8. Direct client database access is default-deny until explicit RLS/API authorization is approved and tested.

## Operating loop

Creator -> Work -> Provenance -> Discovery -> Commercialization -> WIM Market Access -> Transaction/Impact Reference -> Creator Intelligence

## Frontend information architecture

- Universe / Home
- Wall of Creatives
- Creator Archetypes
- Creators
- Works
- Authorship & Witness Grid
- Opportunities
- Commercialization
- Organizations
- Market Access / WIM Exchange
- Research & Publications
- Wealth Ecology Intelligence

## Delivery epics

- CRUDS-E01 — Foundation / bounded-context architecture
- CRUDS-E02 — Creator archetypes & creator profiles
- CRUDS-E03 — Works / portfolios / media registry
- CRUDS-E04 — Authorship, provenance & Witness Grid boundary
- CRUDS-E05 — Opportunities & collaboration workflow
- CRUDS-E06 — Commercialization & WIM market-access integration
- CRUDS-E07 — Settlement / Source Coin reference boundary
- CRUDS-E08 — Wealth Ecology creative-economy intelligence
- CRUDS-E09 — Responsive public frontend modernization and visual QA

## Initial Supabase contract

A dedicated `cruds` schema should be created in the SourceEnergy command backend. Initial entities:

- `creator_archetypes`
- `creators`
- `creator_archetype_memberships`
- `works`
- `work_contributors`
- `provenance_records`
- `witness_verifications`
- `opportunities`
- `opportunity_responses`
- `commercialization_projects`
- `market_access_requests`
- `settlement_references`
- `research_assets`
- `impact_metrics`
- `intelligence_projections`

All integration identifiers are references across bounded contexts; cross-domain authority is not duplicated.
