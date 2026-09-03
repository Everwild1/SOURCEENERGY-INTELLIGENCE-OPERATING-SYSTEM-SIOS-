# SourceEnergy SideKick integration contract

Status: commissioned for the 100-day sprint beginning September 3, 2026 and ending December 11, 2026.

## System-of-record boundaries

| System | Authoritative responsibility | Stored references |
|---|---|---|
| Google Drive | Approved program documents, controlled evidence packages, meeting outputs, and human-readable deliverables | Drive folder/file IDs and URLs |
| GitHub | Versioned data contracts, migrations, validation rules, integration documentation, and release history | Repository, branch, commit, and pull-request references |
| Supabase | Operational program register, node pipeline, sprint checkpoints, evidence metadata, and append-only integration events | Internal UUIDs plus external object references |
| OEL | Governed work items, evidence records, decisions, exceptions, and trusted Sidekick adapter commands | OEL work-item, evidence, site, and decision IDs |

No credentials, private keys, raw banking data, or unnecessary personal data belong in the SideKick registry.

## Canonical portfolio definition

One infrastructure node represents one electric substation, one served community / Opportunity Zone geography, and one 5 MW solar plant.

- TAM management case: 5,000 nodes / 25 GW / $27.5B
- SAM management case: 500 nodes / 2.5 GW / $2.75B
- SOM management case: 25 nodes / 125 MW / $137.5M

These are planning assumptions, not verified inventory, contract awards, valuations, commitments, or forecasts.

## Node identity and lifecycle

Node UID: `SE-IN-[STATE]-[COUNTY]-[0001]`

Lifecycle:

`MAPPED → QOZ_VERIFIED → COMMUNITY_AUTHORIZED → SITE_CONTROLLED → INTERCONNECTION_SCREENED → CONTRACT_QUALIFIED → FINANCED → CONSTRUCTED → ENERGIZED → MEASURED`

Evidence state:

`OBSERVED → TRUSTED → MODELED → AUTHORIZED → EXECUTED → MEASURED → RECALIBRATED`

## Security and authority model

- The `sidekick` schema is private and service-role-only.
- All SideKick tables have row-level security enabled with default-deny client access.
- `sidekick-oel` remains the trusted command adapter and is capped at OEL control level C2.
- Consequential decisions remain human-authorized through existing OEL decision and exception controls.
- The integration event ledger is append-only.
- Google Drive and GitHub content is referenced; it is not copied into operational database fields.

## 100-day checkpoints

| Day | Phase | Gate |
|---:|---|---|
| 10 | Commission | Governance baseline |
| 20 | Commission | Integration architecture |
| 30 | Normalize | Canonical node data contract |
| 40 | Normalize | Candidate inventory intake |
| 50 | Normalize | Opportunity Zone verification |
| 60 | Normalize | Interconnection and site screen |
| 70 | Qualify | Government-contracting qualification |
| 80 | Qualify | Capital and offtake package |
| 90 | Qualify | Demonstrator portfolio selection |
| 100 | Handoff | Executive gate and operating handoff |

## Operational queries

```sql
select * from sidekick.sprint_dashboard order by sprint_day;
select * from sidekick.node_stage_summary order by stage;
```

The sprint dashboard joins SideKick checkpoint metadata to live OEL work-item status. Node totals remain zero until a source inventory is validated and ingested.
