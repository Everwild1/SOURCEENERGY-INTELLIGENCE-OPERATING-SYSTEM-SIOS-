# CRUDS E09 frontend gateway contract

The frontend reads a public-safe, versioned projection from `GET {VITE_CRUDS_API_URL}/universe`. It does not connect directly to the `cruds` schema. This preserves the E01 default-deny invariant while the gateway authenticates callers, applies publication rules and reads Supabase with server-side credentials.

## Read projection

The response declares `contractVersion: cruds-e09.v1` and covers:

| Frontend collection | Authoritative CRUDS sources | Public projection rule |
|---|---|---|
| `archetypes` | `creator_archetypes` | Active canonical taxonomy only |
| `creators` | `creators`, `creator_archetype_memberships` | Published profiles; identity reference remains a projection |
| `works` | `works`, `work_contributors`, `work_media`, `witness_verifications` | Published works; verification status is a Witness Grid reference, never an ownership claim |
| `opportunities` | `opportunities` | Open or under-review discovery records only |
| `research` | `research_assets` | Source-backed public publications only |
| `intelligence` | `impact_metric_registry`, `impact_metrics`, `intelligence_projections` | Active, methodology-versioned projections with measurement kind and provenance |

The `contractCoverage` object must enumerate E01 through E08 so incompatible or incomplete gateway payloads fail closed in `validateUniverse`.

## Command boundaries

Future authenticated commands use gateway endpoints rather than direct Data API writes:

- `POST /opportunities/{id}/responses` creates a non-binding `opportunity_responses` record. It creates no contract, transaction or award.
- `POST /works/{id}/witness-requests` creates `witness_verification_requests`; Witness Grid or an approved evidence authority owns verification.
- `POST /commercialization/{id}/market-access-requests` creates an outbound `market_access_requests` reference; WIM Exchange owns market workflow.
- `POST /commercialization/{id}/settlement-requests` requires an idempotency key and creates orchestration only; approved external rails or Source Coin own finality and ledger effects.

The bundled preview data remains active when `VITE_CRUDS_API_URL` is absent. Preview interactions are local and transmit nothing.

## Security posture

- Never ship a Supabase secret/service-role key in the Vite bundle.
- Keep all 21 `cruds` tables RLS-enabled and direct `anon` / `authenticated` grants revoked unless a separately reviewed policy explicitly changes the access model.
- Apply publication, identity, evidence and role checks in the gateway; do not infer authority from user-editable metadata.
- Preserve correction history and methodology versions in every relevant projection.
