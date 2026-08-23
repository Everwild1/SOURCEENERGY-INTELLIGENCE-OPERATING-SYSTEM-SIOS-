# Legacy Public Schema Recovery — Issue #178

Status: forensic recovery complete; migration implementation pending fresh-branch proof.

## Root cause
Production contains five legacy public relations that were present before the recorded hardening migration `20260820172311_shared_public_schema_security_remediation`, but several of their creation statements are absent from authoritative migration history. Fresh Supabase branches therefore fail when that migration assumes the relations already exist.

Affected relations:
- `public.codex_registry`
- `public.scroll_library`
- `public.dominion_grid`
- `public.ssr_spatial_registry`
- `public.anchor_tiles`

## Authoritative design evidence recovered from SourceEnergy Ecosystem Drive

### Registry truth
The 392-scroll Dominion Grid Registry defines each scroll with identification, title, series, Dominion Cube, layer, mandate/function, status, Scrollkeeper, integration nodes, and linked scrolls. The production `codex_registry` is a reduced compatibility projection of this registry truth.

The engineering-grade Dominion Grid SSR PRD further defines the canonical registry `scrolls` table with:
`id`, `scroll_number`, `title`, `phase`, `series`, `layer`, `dominion_cube`, `status`, `scrollkeeper`, `mandate`, `linked_scrolls_json`, `source_type`.

### Spatial truth
SETC-004 defines the canonical spatial registry object model and requires stable cube identity, layer, spatial reference, geometry hash, coordinate reference system, jurisdiction/stewardship/mandate references, linked assets, operational status, source reference, validation status, and privacy class.

The SSR engineering PRD specifies PostgreSQL + PostGIS and a canonical `cubes` model with `cube_uid`, canonical address, What3Words anchor, Z index, geometry reference, macro layer, vertical datum, metadata and creation timestamp. It explicitly separates registry truth, execution truth, and spatial truth.

## Production forensic snapshot

### `codex_registry`
Columns: `id uuid PK`, `scroll_id text UNIQUE NOT NULL`, `name text NOT NULL`, `layer text`, `dominion_cube text`, `status text`, `function text`, `codex_group text`, `priority text`, `created_at timestamptz default now()`.
Current rows: 6 anchor records (`#026`, `#038`, `#212`, `#222`, `#411`, `ROOT`).

### `scroll_library`
Columns: `id uuid PK`, `title text NOT NULL`, `scroll_id text FK -> codex_registry(scroll_id) ON DELETE SET NULL`, `summary text`, `category text`, `status text`, `created_at timestamptz default now()`.
Current rows: 0.

### `dominion_grid`
Columns: `id uuid PK`, `cube_id text UNIQUE NOT NULL`, `layer text`, `function text`, `linked_scroll_id text FK -> codex_registry(scroll_id) ON DELETE SET NULL`, `status text`, `created_at timestamptz default now()`.
Current rows: 0.

### `ssr_spatial_registry`
Columns: `id uuid PK`, `coordinate text NOT NULL`, `z_level text`, `cube_uid text UNIQUE`, `use_case text`, `linked_scroll_id text FK -> codex_registry(scroll_id) ON DELETE SET NULL`, `system_type text`, `operational_status text`, `created_at timestamptz default now()`.
Current rows: 0.

### `anchor_tiles`
Columns: `anchor_tile_id text PK`, `w3w_address text UNIQUE NOT NULL`, latitude/longitude, activation/status, CRS/vertical datum, source provenance, PostGIS `geom`, authority signature, metadata SHA-256 and creation timestamp. Includes coordinate range checks, What3Words-format check, SHA-256 format check, and spatial/date indexes.
Current rows: 0.

## Architecture decision
These five relations are **legacy compatibility structures**, not the target canonical model. Four contain no production data. `codex_registry` contains only six anchor records and is a reduced projection of the richer Drive-defined registry truth.

Therefore:
1. Preserve the legacy relation shapes in a source-controlled compatibility baseline so historical migrations can replay.
2. Do not populate the four empty relations merely for compatibility.
3. Preserve the six `codex_registry` anchor records only through a separate, explicit data-seed migration if required by runtime dependencies.
4. Treat the Drive-defined `scrolls`/SSR model and SETC specifications as the forward canonical architecture.
5. Add deprecation/migration mapping from legacy compatibility relations to canonical registry/spatial structures rather than expanding the legacy schema.
6. Do not edit already-applied production migration history in place.

## Required proof before closing #178
- Add a pre-hardening compatibility-baseline migration containing the exact recovered DDL and constraints.
- Ensure ordering places it before `20260820172311_shared_public_schema_security_remediation` in fresh environments without rewriting an already-applied production migration.
- Create a new isolated Supabase branch from the repaired authoritative migration sequence.
- Require zero migration failures.
- Verify all five relation shapes/constraints/indexes against this forensic snapshot.
- Re-run security advisors.
- Attach evidence to issue #178 and TST pilot manifest.

Production remains NO-GO until fresh-branch replay passes.