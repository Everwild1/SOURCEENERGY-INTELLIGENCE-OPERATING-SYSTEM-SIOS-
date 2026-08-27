# CRUDS Universe public publication policy

**Policy version:** `cruds-publication.v1`

**Applies to:** `GET /functions/v1/cruds-public-universe/universe`

## Purpose

The public gateway projects a deliberately small, read-only view of the authoritative `cruds` schema. It never grants a browser direct database access and never converts a CRUDS record into legal, authorship, market, transaction, or settlement authority.

## Eligible records

Only the following records may be returned:

- active canonical creator archetypes;
- creators with `published = true`, with their archetype classifications and published-work count;
- works with `publication_status = 'published'`, plus the latest Witness Grid status reference;
- opportunities in `open` or `under_review` state whose configured publication window is active;
- research assets with a publication date on or before the request date;
- active impact metrics whose registry definition is also active.

An empty eligible collection is returned as an empty array. Production must not substitute synthetic creator, work, opportunity, research, or intelligence records.

## Excluded information

The gateway excludes private evidence payloads, provenance JSON, response records, settlement requests, market-access request payloads, internal confidence evidence, identity credentials, secrets, and all unpublished or restricted records. Identity references that appear on a published creator remain projections to the approved identity authority.

## Access and authority controls

- The browser calls the same-origin Sites worker at `/api/universe`.
- The worker authenticates to the Edge Function with the project's publishable key, stored as a Sites runtime secret.
- The Edge Function performs server-side reads and exposes only the fields enumerated by `cruds-e09.v1`.
- The direct `anon` and `authenticated` grants on all 21 CRUDS tables remain revoked; RLS remains enabled.
- The endpoint accepts `GET` only, applies a bounded result limit and emits a short cache lifetime.
- Opportunity interest stays local until a separately approved authenticated command release exists.

## Corrections and withdrawal

Unpublishing, archiving, restricting, superseding, or withdrawing a record removes it from the next uncached projection. Correction history remains authoritative in the backend even when it is not included in the public payload.

## Release and rollback

Production activation requires successful contract tests, frontend build, Sites packaging tests, a live gateway smoke test, security-advisor review, and an owner-controlled Sites deployment. Rollback consists of removing the gateway runtime variables or redeploying the previous saved Sites version; neither action changes authoritative CRUDS data.
